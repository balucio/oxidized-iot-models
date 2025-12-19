# Oxidized IoT Models

This repository contains custom **Oxidized models for IoT devices**, designed to backup the configuration of **Tasmota** and **OpenBeken** devices using Oxidized.
I created this project mainly for personal backup needs, and it is intentionally kept simple.

Currently supported devices:
- **Tasmota**
- **OpenBeken**

---

## Tasmota Model

The **Tasmota** model is implemented as an **`exec` model**. It uses the `decode-config.py` utility to download and decode the binary configuration dump (`.dmp`). The final backup file contains both the decoded JSON configuration and the full binary dump (Base64 encoded) of the Tasmota device.

**Requirements:**
* Python 3.
* `decode-config.py` must be available on the Oxidized host (the default path is `/usr/bin/decode-config.py`).

> **Note:** I plan to remove this dependency in the future.

---

## OpenBeken Model

The **OpenBeken** model uses the **HTTP input**. The model automatically retrieves the pin configuration from `/api/pins`, downloads the internal filesystem (LFS) via `/api/lfs/`, and fetches the binary configuration dump directly from the flash memory.

All decoding and formatting is handled **directly inside the model**, so no external tools or scripts are required. Compared to the Tasmota model, this implementation is fully self-contained but more simple.

---

## Installation

To use these models, copy the `.rb` files into your Oxidized models directory:

```bash
cp *.rb ~/.config/oxidized/model/
```
Then, restart the Oxidized service to apply the changes.

> **Note:** Ensure `/usr/bin/decode-config.py` is installed.


## Example Oxidized Configuration (router.db)

```
rf-transmitter.example.com:tasmota:::exec
rack-cooler.example.com:openbeken:::http
```
