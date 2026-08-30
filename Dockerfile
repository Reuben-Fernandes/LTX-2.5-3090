# ── Base ─────────────────────────────────────────────────────────
# CUDA devel image (not plain ubuntu) — needed for nvcc to compile
# SageAttention2 from source.
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV HF_XET_HIGH_PERFORMANCE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /workspace
# ── System Dependencies ──────────────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-dev \
        git \
        git-lfs \
        ffmpeg \
        curl \
        libgl1 \
        libglib2.0-0 \
        build-essential \
        ninja-build \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/lib/python3.12/EXTERNALLY-MANAGED
# ── PyTorch (cu118 — widest driver compatibility for a loose
#    RunPod "min CUDA 12.0" filter; SageAttention2 only needs >=12.0
#    on Ampere regardless of which torch build is used) ────────────
RUN pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu118 \
    --quiet
# ── ComfyUI ──────────────────────────────────────────────────────
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
RUN pip install -r /workspace/ComfyUI/requirements.txt --quiet
# ── Python Dependencies ──────────────────────────────────────────
RUN pip install \
        "huggingface_hub[cli]" \
        hf_transfer \
        --quiet
# ── Custom Nodes ─────────────────────────────────────────────────
RUN cd /workspace/ComfyUI/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager && \
    git clone https://github.com/rgthree/rgthree-comfy && \
    git clone https://github.com/chrisgoringe/cg-use-everywhere
RUN for dir in /workspace/ComfyUI/custom_nodes/*/; do \
        if [ -f "$dir/requirements.txt" ]; then \
            pip install -r "$dir/requirements.txt" --quiet || true; \
        fi \
    done
# ── SageAttention2 (Ampere / RTX 3090 — compiled from source) ────
# SageAttention3 is Blackwell-only (SM120); 3090 is SM86, so we build
# the 2.x line instead. Requires nvcc from the devel base image above.
# TORCH_CUDA_ARCH_LIST is required because GitHub Actions runners have
# no GPU — setup.py can't auto-detect compute capability without one.
ENV TORCH_CUDA_ARCH_LIST="8.6"
RUN git clone https://github.com/thu-ml/SageAttention.git /tmp/SageAttention && \
    cd /tmp/SageAttention && \
    python3 setup.py install && \
    cd / && rm -rf /tmp/SageAttention
# ── Ports ────────────────────────────────────────────────────────
EXPOSE 8188
EXPOSE 8888
# ── Start Script ─────────────────────────────────────────────────
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]
