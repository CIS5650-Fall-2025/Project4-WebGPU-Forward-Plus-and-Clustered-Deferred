WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Zhaojin Sun
  * www.linkedin.com/in/zjsun
* Tested on: Windows 11, i9-13900HX @ 2.2GHz 64GB, RTX 4090 Laptop 16GB

### Live Demo

[Play around as you like!](https://zjsun1017.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/)

### Demo Video/GIF

[![](img/video.mp4)](TODO)


### 1. Project Overview
This project is about learning to use WebGPU and implementing some accelerated rendering functions. The project is very challenging for me because I didn’t have any prior experience with JavaScript, and the design concepts of WebGPU are very different from CUDA. Particularly, the complex Binding Group and the many built-in pipelines make it hard for someone with limited experience like me to adapt. That said, the overall content of this project is still very interesting, especially as faster methods are implemented, the increase in frame rate becomes quite noticeable.

**Features implemented**
- Naive Forward Rendering
- Clustered Forward Plus Rendering
- Clustered Deferred Rendering
- [Extra Credit +5] Clustered Deferred Rendering with Compact G-Buffer

### 2. Features and Performance Analysis
#### (i) Speed Comparison among All rendering Methods




#### (ii) Naive Rendering Analysis

#### (iii) Clustered Forward Plus Rendering

#### (iv) Clustered Deferred Rendering

#### (iv) [Extra Credits] Compact G-Buffer

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
