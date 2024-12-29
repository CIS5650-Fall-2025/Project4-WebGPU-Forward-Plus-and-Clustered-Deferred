// CHECKITOUT: feel free to add more math utility functions here

import { vec3 } from "wgpu-matrix";

export function toRadians(degrees: number) {
    return degrees * Math.PI / 180;
}

export function toDegrees(radians: number) {
    return radians * 180 / Math.PI;
}

// h in [0, 1]
export function hueToRgb(h: number) {
    let f = (n: number, k = (n + h * 6) % 6) => 1 - Math.max(Math.min(k, 4 - k, 1), 0);
    return vec3.lerp(vec3.create(1, 1, 1), vec3.create(f(5), f(3), f(1)), 0.8);
}