# WebGL Forward+ and Clustered Deferred Shading

======================

**University of Pennsylvania, CIS 5650: GPU Programming and Architecture, Project 4 - Forward+ & Clustered Deferred Shading**

- Jordan Hochman
  - [LinkedIn](https://www.linkedin.com/in/jhochman24), [Personal Website](https://jordanh.xyz), [GitHub](https://github.com/JHawk0224)
- Tested on: **Google Chrome (130.0.6723.59)** and **Opera GX (LVL6 - 114.0.5282.106)** on
  Windows 11, Ryzen 7 5800 @ 3.4GHz 32GB, GeForce RTX 3060 Ti 8GB (Compute Capability: 8.6)

## Welcome to my WebGPU Graphics Pipelines Project!

In this project, I implemented multiple graphics pipelines using WebGPU. The first is a naive implementation that runs a normal vertex shader and then fragment shader pass. The second is a 3D-clustered Forward+ pass with a compute shader to determine which clusters are affected by which lights, and the last is a also a 3D-clustered pass, but this time it's deferred. The colors (albedos), normals, positions, and depths are precomputed into a buffer at once, and then these are combined in the final fragment shader as opposed to the original architecture (it uses the same compute shader for the lights). More details can be found in `INSTRUCTIONS.md` [here](INSTRUCTIONS.md).

### Demo Video/GIF

![](images/deferred-5000.gif)

Here is a demo GIF of it running. Note that the FPS cap/framiness is due to the GIF itself, and not the actual graphics pipeline. The GIF only has so many frames per second, so instead, look at the FPS counter in the top left.

### Live Demo

[![](images/deferred-2000.jpg)](https://jhawk0224.github.io/CIS5650-Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)

Try out the demo [here](https://jhawk0224.github.io/CIS5650-Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)! You can select which pipeline is being used, the naive one, the forward+ one, or the clustered deferred one.

### (TODO: Your README)

_DO NOT_ leave the README to the last minute! It is a crucial part of the
project, and we will not be able to grade you without a good README.

This assignment has a considerable amount of performance analysis compared
to implementation work. Complete the implementation early to leave time!

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
