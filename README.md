# Synapse
### The Bridge Between the Web and Your Timeline.

<div style="display: flex; justify-content: space-between; align-items: center;">
  <img src="DaVinci Resolve - Media Prep Tool 1.png" height="300">
  <img src="DaVinci Resolve - Media Prep Tool 2.png" height="300">
</div>


**Synapse** is an open-source media acquisition and processing tool designed specifically for video editors, content creators, and motion designers. 

It acts as a unified interface leveraging the power of **yt-dlp** and **FFmpeg** to download, convert, and standardize media files in a single click.

---

## 🚀 The Problem

Video editors—especially those using **DaVinci Resolve (Free Version) on Linux**—face a constant struggle:
1.  **Codec Incompatibility:** Web videos often come in formats (variable frame rates, specific AAC audio, or non-compliant H.264/AV1) that cause "Media Offline" errors or glitchy playback in professional NLEs.
2.  **The "Terminal Fatigue":** The workflow usually involves downloading a file, realizing it doesn't work, opening a terminal, remembering complex FFmpeg flags, converting it, and finally importing it.

## 💡 The Solution: Synapse

Synapse automates this entire pipeline. It downloads the highest quality video/audio and **immediately** converts it into an edit-friendly format (such as PCM Audio/standardized containers) before you even see the file. 

**Stop fighting with codecs. Just click, download, and drag to your timeline.**

---

## ✨ Key Features

### 🎬 For Video Editors (The Linux Fix)
* **Timeline Ready:** Automatically remuxes or transcodes downloads to ensure compatibility with DaVinci Resolve, Premiere Pro, and Final Cut.
* **Linux Savior:** Specifically solves the missing AAC/H.264 codec support issues found in the free version of DaVinci Resolve on Linux distributions (Ubuntu, Fedora, Arch, etc.).
* **Audio Correction:** Automatically converts web audio to PCM/WAV where necessary to prevent sync drift.

### 🛠️ Universal Converter
* **Video:** Convert any format to MP4, MOV, MKV, or editing codecs like DNxHR/ProRes (planned).
* **Audio:** Extract audio from videos or convert music files.
* **Images:** Batch convert images (PNG to JPG, WebP to PNG), resize assets, or create Icons.
* **GIF to Video:** Turn GIFs into loopable video files for your edits.

### ⚡ Powered By
* **yt-dlp:** The gold standard for media downloading.
* **FFmpeg:** The swiss-army knife of media processing.

---

## 📦 Installation

*(Developer Note: Add your specific installation instructions here depending on if it is Python, Electron, etc. Below is a generic placeholder)*

---

## 📖 Usage

1.  **Paste URL:** Copy a link from YouTube, Vimeo, or other supported sites.
2.  **Select Target:** Choose "Video (Edit Ready)", "Audio Only", or strictly "Convert File" if you already have the file locally.
3.  **Execute:** Click the button. Synapse handles the download and the FFmpeg conversion in the background.
4.  **Edit:** The output file is ready to be dragged directly into DaVinci Resolve without errors.

---

## 🤝 Contributing

We want Synapse to help as many editors as possible, regardless of their Operating System. 

If you have ideas for better FFmpeg presets, UI improvements, or support for more distros, please feel free to fork this repository and submit a Pull Request.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
