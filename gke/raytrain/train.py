
import ray

ray.init(
    runtime_env={
        "pip": [
            "datasets",
            "evaluate",
            "transformers>=4.26.0",
            "torch>=1.12.0",
            "lightning>=2.0",
        ]
    }
)

MODEL_NAME = "databricks/dolly-v2-7b"

#import ray
import pandas as pd
from datasets import load_dataset
from transformers import AutoTokenizer, AutoModelForCausalLM

def split_text(batch: pd.DataFrame) -> pd.DataFrame:
    text = list(batch["text"])
    flat_text = "".join(text)
    split_text = [
        x.strip()
        for x in flat_text.split("\n")
        if x.strip() and not x.strip()[-1] == ":"
    ]
    return pd.DataFrame(split_text, columns=["text"])


def tokenize(batch: pd.DataFrame) -> dict:
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, padding_side="left")
    tokenizer.pad_token = tokenizer.eos_token
    ret = tokenizer(
        list(batch["text"]),
        truncation=True,
        max_length=256,
        padding="max_length",
        return_tensors="np",
    )
    ret["labels"] = ret["input_ids"].copy()
    return dict(ret)

hf_dataset = load_dataset("tiny_shakespeare")
train_ds = ray.data.from_huggingface(hf_dataset["train"])

# First split the dataset into multiple sentences.
train_ds = train_ds.map_batches(split_text, batch_format="pandas")
train_ds.take(10)

# Then tokenize the dataset.
train_ds = train_ds.map_batches(tokenize, batch_format="pandas")

import torch
import lightning.pytorch as pl

class DollyV2Model(pl.LightningModule):
    def __init__(self, lr=2e-5, eps=1e-8):
        super().__init__()
        self.save_hyperparameters()
        self.lr = lr
        self.eps = eps
        self.model = AutoModelForCausalLM.from_pretrained(MODEL_NAME)

    def forward(self, batch):
        outputs = self.model(
            batch["input_ids"], 
            attention_mask=batch["attention_mask"], 
            labels=batch["labels"]
        )
        return outputs.loss

    def training_step(self, batch, batch_idx):
        loss = self.forward(batch)
        self.log("train_loss", loss, prog_bar=True, on_step=True)
        return loss

    def configure_optimizers(self):
        if self.global_rank == 0:
            print(self.trainer.model)
        return torch.optim.AdamW(self.trainer.model.parameters(), lr=self.lr, eps=self.eps)
    

import functools
import lightning.pytorch as pl 

from torch.distributed.fsdp.wrap import transformer_auto_wrap_policy
from torch.distributed.fsdp import ShardingStrategy, BackwardPrefetch
from transformers.models.gpt_neox.modeling_gpt_neox import GPTNeoXLayer

from ray.train.lightning import RayFSDPStrategy


# Define the model sharding policy:
# Wrap every GPTNeoXLayer as its own FSDP instance
auto_wrap_policy = functools.partial(
    transformer_auto_wrap_policy,
    transformer_layer_cls = {GPTNeoXLayer}
)

fsdp_strategy = RayFSDPStrategy(
    sharding_strategy=ShardingStrategy.FULL_SHARD,
    backward_prefetch=BackwardPrefetch.BACKWARD_PRE,
    forward_prefetch=True,
    auto_wrap_policy=auto_wrap_policy,
    limit_all_gathers=True,
    activation_checkpointing=[GPTNeoXLayer],
)

num_workers = 8
batch_size_per_worker = 10

from ray.train import Checkpoint
from ray.train.lightning import RayLightningEnvironment, RayTrainReportCallback, prepare_trainer

# Training function for each worker
def train_func(config):
    lr = config["lr"]
    eps = config["eps"]
    strategy = config["strategy"]
    batch_size_per_worker = config["batch_size_per_worker"]

    # Model
    model = DollyV2Model(lr=lr, eps=eps)

    # Ray Data Ingestion
    train_ds = ray.train.get_dataset_shard("train")
    train_dataloader = train_ds.iter_torch_batches(batch_size=batch_size_per_worker)

    # Lightning Trainer
    trainer = pl.Trainer(
        max_epochs=1, 
        devices="auto",
        accelerator="auto", 
        precision="16-mixed",
        strategy=strategy,
        plugins=[RayLightningEnvironment()],
        callbacks=[RayTrainReportCallback()],
        enable_checkpointing=False,
    )

    trainer = prepare_trainer(trainer)

    trainer.fit(model, train_dataloaders=train_dataloader)

storage_path="/gcs-dir"  # TODO: Set up cloud storage
# storage_path="/mnt/path/to/nfs"     # TODO: Alternatively, set up NFS
from ray.train.torch import TorchTrainer
from ray.train import RunConfig, ScalingConfig, CheckpointConfig

# Save Ray Train checkpoints according to the performance on validation set
run_config = RunConfig(
    name="finetune_dolly-v2-7b",
    storage_path=storage_path,
    checkpoint_config=CheckpointConfig(num_to_keep=1),
)

# Scale the FSDP training workload across 16 GPUs
# You can change this config based on your compute resources.
scaling_config = ScalingConfig(
    num_workers=num_workers, use_gpu=True, trainer_resources={"memory": 100 * 1024 ** 3}
)

# Configuration to pass into train_func
train_config = {
    "lr": 2e-5,
    "eps": 1e-8,
    "strategy": fsdp_strategy,
    "batch_size_per_worker": 10
}

# Define a TorchTrainer and launch you training workload
ray_trainer = TorchTrainer(
    train_func,
    train_loop_config=train_config,
    run_config=run_config,
    scaling_config=scaling_config,
    datasets={"train": train_ds},
)
result = ray_trainer.fit()

result

