# Portable AI USB 🧠💾

Turn any USB drive into a **portable, local AI server**. Plug it into a Windows PC, run one script, and chat with an LLM in your browser — **nothing is installed on the host computer**. Everything (the engine and the models) lives on the USB stick.

Powered by [llama.cpp](https://github.com/ggml-org/llama.cpp).

## ✨ Features

- **Fully portable** — runs entirely from the USB, leaves no trace on the host PC.
- **Works on any drive letter** — uses relative paths, so it doesn't matter if your USB is `E:`, `F:`, or `G:`.
- **Auto GPU detection** — picks the best engine for the machine: NVIDIA (CUDA), Intel/AMD/NVIDIA (Vulkan), or CPU-only fallback.
- **One-click start/stop** — launches the server and opens your browser automatically.
- **Bring your own models** — works with any `.gguf` model file.

## 📋 Requirements

- Windows 10 / 11
- A USB drive (16 GB+ recommended, depending on model size)
- An internet connection **for first-time setup only** (to download llama.cpp)

## 🚀 Quick Start

**1. Set up the USB** (run once)

Copy all three `.bat` files to a folder, then run:

```
setup.bat
```

It will let you pick your USB drive, optionally format it, download llama.cpp, and create this structure on the drive:

```
AI_USB/
├── models/       <- put your .gguf model files here
├── scripts/      <- startserver.bat & stopserver.bat
└── llama_cpp/    <- the AI engine (auto-downloaded)
```

**2. Add a model**

Drop any `.gguf` model into the `AI_USB/models/` folder. Free models are on [Hugging Face](https://huggingface.co/models?other=gguf) — search for `Mistral`, `Gemma`, or `Qwen` + `Instruct GGUF`.

**3. Run it**

From the USB, run:

```
AI_USB/scripts/startserver.bat
```

Pick your model, choose whether to use the GPU, and your browser opens automatically at:

```
http://localhost:8080
```

## 🛑 Stopping the Server

Just close the server window, or run:

```
AI_USB/scripts/stopserver.bat
```

When it's done, you can safely remove the USB drive.

## ⚙️ Default Settings

These are set in `startserver.bat` and easy to edit:

- **Port:** `8080`
- **Context size:** `4096` tokens
- **GPU layers:** all (`-ngl 99`) when GPU is enabled, otherwise CPU with one core left free

## ❓ FAQ

**Does it install anything on the PC?**
No. The engine and models stay on the USB. The only thing it touches is RAM/GPU while running.

**Which engine should I download in setup?**
Choose **"All three"** (option 4) for maximum compatibility — `startserver.bat` will automatically pick the right one for each computer.

**No GPU acceleration available?**
Re-run `setup.bat` and choose Vulkan (option 3) or All (option 4).

## 📜 License
feel free to use, modify, and share.

---

*Built by me, with a little help from GLM.*
