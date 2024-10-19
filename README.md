WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Joanna Fisch
  * [LinkedIn](https://www.linkedin.com/in/joanna-fisch-bb2979186/), [Website](https://sites.google.com/view/joannafischsportfolio/home)
* Tested on: Windows 11, i7-12700H @ 2.30GHz 16GB, NVIDIA GeForce RTX 3060 (Laptop)

### Live Demo

[![](img/thumb.png)](http://TODO.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)

### Demo Video/GIF

![ScenePic](https://github.com/user-attachments/assets/6e98a652-fbbd-45a6-8d3f-16ad04ae1339)

https://github.com/user-attachments/assets/b7489c6c-6df0-490f-b5c1-9a3dfee5fc16


### Performance Analysis

1. Is one faster?
   Clustered Deferred shading consistently outperforms both Naive and Forward+ methods, especially with increasing numbers of lights. The gap becomes more pronounced with larger light counts:
   At 5000 lights, Forward+ takes 593 ms, while Clustered Deferred takes only 175 ms.
   Forward+ shows improvements over the Naive approach but doesn’t scale as efficiently as Clustered Deferred, especially with higher light counts.

2. Workload differences:
   Forward+ is faster with smaller light counts but struggles to scale due to its per-tile light list generation.
   Clustered Deferred shading handles higher numbers of lights better since it clusters both geometry and lights, reducing redundant lighting calculations.

<table>
  <tr>
    <td><img src="img/effectLights.png" /></td>
  </tr>
  <tr>
    <td colspan="3" align="center"><i> Cluster Grid (16,16,24), Cluster Workgroup Size (4,4,4), Max Number of Lights per Cluster 1000</i></td>
  </tr>
</table>

<table>
  <tr>
    <td><img src="img/effectClusterTiles.png" /></td>
  </tr>
  <tr>
    <td colspan="3" align="center"><i> Number of Lights 500, Cluster Workgroup Size (4,4,4), Max Number of Lights per Cluster 1000</i></td>
  </tr>
</table>

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
