# FastVLM Model Assets

Populate `model/` from the repository root:

```sh
just download-model
```

Direct script invocation is also available:

```sh
bash scripts/get_pretrained_mlx_model.sh --model 0.5b --dest app/FastVLM/model
```

The downloaded model is intentionally not committed.
