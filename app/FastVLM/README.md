# FastVLM Model Assets

Stage the local development copy of the model from the repository root:

```sh
just download-model
```

That command now downloads into `app/Generated/FastVLMODR/model`, which is the repo-local staging directory used by the app target's On-Demand Resource setup.

Direct script invocation is also available if you need a custom destination:

```sh
bash scripts/get_pretrained_mlx_model.sh --model 0.5b --dest app/Generated/FastVLMODR/model
```

The downloaded model is intentionally not committed.
