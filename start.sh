#!/bin/bash
#
# LTX-2.5 Pod start script (RTX 3090 / SageAttention2 build)
#
set -e
COMFYUI_DIR=/workspace/ComfyUI
echo ""
echo "########################################"
echo "#    LTX-2.5 (3090 + SageAttn2) - Start #"
echo "########################################"
echo ""
if [[ -z "$HF_TOKEN" ]]; then
    echo "ERROR: HF_TOKEN not set. Add it as a RunPod environment variable."
    exit 1
fi
export HF_TOKEN
export HF_XET_HIGH_PERFORMANCE=1
export HF_HUB_ENABLE_HF_TRANSFER=1
# ── Download Models ──────────────────────────────────────────────
echo "  → Checking models..."
python3 << PYEOF
import os, shutil
from huggingface_hub import hf_hub_download
token = os.environ["HF_TOKEN"]
base = "$COMFYUI_DIR/models"
models = [
    ("Lightricks/LTX-2.5", "diffusion_models/ltx-2.5-22b-distilled-transformer-comfy-int8-convrot.safetensors", "diffusion_models"),
    ("Lightricks/LTX-2.5", "latent_upscale_models/ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors", "latent_upscale_models"),
    ("Lightricks/LTX-2.5", "text_encoders/gemma4-12b-with-proj-ltx-2.5-comfy-int8-convrot.safetensors", "text_encoders"),
    ("Lightricks/LTX-2.5", "vae/ltx-2.5-audio-vae-bf16.safetensors", "vae"),
    ("Lightricks/LTX-2.5", "vae/ltx-2.5-video-vae-bf16.safetensors", "vae"),
    ("Comfy-Org/gemma-4", "text_encoders/gemma4_e2b_it_int8_convrot.safetensors", "text_encoders"),
]
for repo_id, filename, dest_folder in models:
    save_name = filename.split("/")[-1]
    dest = os.path.join(base, dest_folder, save_name)
    if os.path.exists(dest):
        print(f"  ⏭  Already exists: {save_name}")
        continue
    os.makedirs(os.path.join(base, dest_folder), exist_ok=True)
    print(f"  → Downloading: {save_name}")
    path = hf_hub_download(
        repo_id=repo_id,
        filename=filename,
        token=token,
        local_dir="/tmp/hf_dl",
        local_dir_use_symlinks=False
    )
    shutil.move(path, dest)
    print(f"  ✓ Saved: {save_name}")
print("")
print("✓ All models ready")
PYEOF
# ── Launch ComfyUI ───────────────────────────────────────────────
echo "  → Launching ComfyUI on port 8188 (SageAttention2 enabled)..."
echo ""
exec python3 "$COMFYUI_DIR/main.py" \
    --listen 0.0.0.0 \
    --port 8188 \
    --enable-cors-header \
    --use-sage-attention
