// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput {
    @location(0) pos: vec3<f32>,
    @location(1) nor: vec3<f32>,
    @location(2) uv: vec2<f32>,
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4<f32> {
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5) {
        discard;
    }

   
    let screenPos = camera.viewProjMat * vec4<f32>(in.pos, 1.0);
    let ndcPos = screenPos.xyz / screenPos.w;
    let clusterGridSizeX = ${clusterXsize };
    let clusterGridSizeY = ${clusterYsize };
    let clusterGridSizeZ = ${clusterZsize };
    
    

  
    let clusterX = u32((ndcPos.x + 1.0) * 0.5 * f32(clusterGridSizeX));
    let clusterY = u32((ndcPos.y + 1.0) * 0.5 * f32(clusterGridSizeY));
    let clusterZ = u32(ndcPos.z * f32(clusterGridSizeZ));

   
    let clusterXClamped = min(clusterX, u32(clusterGridSizeX) - 1u);
    let clusterYClamped = min(clusterY,u32( clusterGridSizeY) - 1u);
    let clusterZClamped = min(clusterZ, u32(clusterGridSizeZ) - 1u);

   
    let clusterIndex = clusterZClamped * u32(clusterGridSizeX) * u32(clusterGridSizeY) +
                       clusterYClamped * u32(clusterGridSizeX) +
                       clusterXClamped;
    
    // let numberL = f32(clusterSet.clusters[clusterIndex].numLights);
    // if (clusterSet.clusters[clusterIndex].numLights > 0){
    //     return vec4<f32>(numberL/35.00,numberL/35.00,numberL/35.00, 1.0);
    // }
    // else{
    //     return vec4<f32>(0.0,0.0,0.0, 1.0);
    // }
    
    
    
    //var finalColor = vec3<f32>(0.0,0.0,0.0);
    
    var totalLightContrib = vec3<f32>(0.0,0.0,0.0);
    for (var i = 0u; i < clusterSet.clusters[clusterIndex].numLights; i++) {
        
       
        let lightIdx = clusterSet.clusters[clusterIndex].lightIndices[i];
        
        let light = lightSet.lights[lightIdx];
        
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
        
        
        
    }

    let finalColor = diffuseColor.rgb * totalLightContrib;
    
    return vec4<f32>(finalColor, 1.0);
    
}