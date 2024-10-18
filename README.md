WebGL Forward+ and Clustered Deferred Shading
======================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 4**

* Joanna Fisch
  * [LinkedIn](https://www.linkedin.com/in/joanna-fisch-bb2979186/), [Website](https://sites.google.com/view/joannafischsportfolio/home)
* Tested on: Windows 11, i7-12700H @ 2.30GHz 16GB, NVIDIA GeForce RTX 3060 (Laptop)

### Live Demo

[![](img/thumb.png)](http://TODO.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred)

### Demo Video/GIF

[![](img/VideoDemo.mp4)](TODO)

### Performance Analysis

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
