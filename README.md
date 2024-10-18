WebGPU Forward Clustered and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Zixiao Wang
  * [LinkedIn](https://www.linkedin.com/in/zixiao-wang-826a5a255/)
* Tested and rendered on: Windows 11, i7-12800H @ 2.40 GHz 32GB, GTX 3070TI (Laptop)

### Live Demo

[Live Demo Link](https://lanbiubiu1.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/)

### Demo Video/GIF
#### 5000 Lights
![](img/demo4.gif)

#### 5000 Lights, interactive
![](img/demo6.gif)





### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)

#### code reference
- WebGPU API: detail about the function parameters and return types of [createSampler()](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/createSampler)
- WGSL: [Depth Texture Types](https://www.w3.org/TR/WGSL/#texture-depth)
- Nividia CG Tutorial: gets really confusing while transforming among multiple spaces in shaders code, good to reference before starting writing [Coordinate Systems](https://developer.download.nvidia.com/CgTutorial/cg_tutorial_chapter04.html)
- use as a reference for computing shader: https://github.com/toji/webgpu-clustered-shading/blob/main/js/webgpu-renderer/shaders/clustered-compute.js
  ```
    clusters.bounds[tileIndex].minAABB = min(min(minPointNear, minPointFar),min(maxPointNear, maxPointFar));
    clusters.bounds[tileIndex].maxAABB = max(max(minPointNear, minPointFar),max(maxPointNear, maxPointFar));
  ```

