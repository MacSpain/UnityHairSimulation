using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class OldShell : MonoBehaviour {
    public Mesh shellMesh;
    public Shader shellShader;

    public bool updateStatics = true;

    // These variables and what they do are explained on the shader code side of things
    // You can see below (line 70) which shader uniforms match up with these variables
    [Range(1, 256)]
    public int shellCount = 16;

    [Range(0.0f, 1.0f)]
    public float shellLength = 0.15f;

    [Range(0.01f, 3.0f)]
    public float distanceAttenuation = 1.0f;

    [Range(1.0f, 1000.0f)]
    public float density = 100.0f;

    [Range(0.0f, 1.0f)]
    public float noiseMin = 0.0f;

    [Range(0.0f, 1.0f)]
    public float noiseMax = 1.0f;

    [Range(0.0f, 10.0f)]
    public float thickness = 1.0f;

    [Range(0.0f, 10.0f)]
    public float curvature = 1.0f;

    [Range(0.0f, 1.0f)]
    public float displacementStrength = 0.1f;

    public Color shellColor;

    [Range(0.0f, 5.0f)]
    public float occlusionAttenuation = 1.0f;
    
    [Range(0.0f, 1.0f)]
    public float occlusionBias = 0.0f;
    public Transform light;

    private Material shellMaterial;
    private Material[] shellMaterials;
    private GameObject[] shells;

    private Vector3 displacementDirection = new Vector3(0, 0, 0);

    void OnEnable() {
        shellMaterial = new Material(shellShader);
        shellMaterials = new Material[256];

        shells = new GameObject[shellCount];

        for (int i = 0; i < shellCount; ++i) {
            shells[i] = new GameObject("Shell " + i.ToString());
            shells[i].AddComponent<MeshFilter>();
            shells[i].AddComponent<MeshRenderer>();
            
            shells[i].GetComponent<MeshFilter>().mesh = shellMesh;
            shells[i].GetComponent<MeshRenderer>().material = shellMaterial;
            shellMaterials[i] = shells[i].GetComponent<MeshRenderer>().material;
            shells[i].transform.SetParent(this.transform, false);

            // In order to tell the GPU what its uniform variable values should be, we use these "Set" functions which will set the
            // values over on the GPU. 
            shellMaterials[i].SetInt("_ShellCount", shellCount);
            shellMaterials[i].SetInt("_ShellIndex", i);
            shellMaterials[i].SetFloat("_ShellLength", shellLength);
            shellMaterials[i].SetFloat("_Density", density);
            shellMaterials[i].SetFloat("_Thickness", thickness);
            shellMaterials[i].SetFloat("_Attenuation", occlusionAttenuation);
            shellMaterials[i].SetFloat("_ShellDistanceAttenuation", distanceAttenuation);
            shellMaterials[i].SetFloat("_Curvature", curvature);
            shellMaterials[i].SetFloat("_DisplacementStrength", displacementStrength);
            shellMaterials[i].SetFloat("_OcclusionBias", occlusionBias);
            shellMaterials[i].SetFloat("_NoiseMin", noiseMin);
            shellMaterials[i].SetFloat("_NoiseMax", noiseMax);
            shellMaterials[i].SetVector("_ShellColor", shellColor);
            shellMaterials[i].SetVector("_ShellDirection", displacementDirection);
            shellMaterials[i].SetVector("_LightDir", -light.forward);
        }
    }

    void Update() {
        float velocity = 1.0f;
        
        Vector3 direction = new Vector3(0, 0, 0);
        Vector3 oppositeDirection = new Vector3(0, 0, 0);

        // This determines the direction we are moving from wasd input. It's probably a better idea to use Unity's input system, since it handles
        // all possible input devices at once, but I did it the old fashioned way for simplicity.
        direction.x = Convert.ToInt32(Input.GetKey(KeyCode.D)) - Convert.ToInt32(Input.GetKey(KeyCode.A));
        direction.y = Convert.ToInt32(Input.GetKey(KeyCode.W)) - Convert.ToInt32(Input.GetKey(KeyCode.S));
        direction.z = Convert.ToInt32(Input.GetKey(KeyCode.Q)) - Convert.ToInt32(Input.GetKey(KeyCode.E));

        // This moves the ball according the input direction
        Vector3 currentPosition = this.transform.position;
        direction.Normalize();
        currentPosition += direction * velocity * Time.deltaTime;
        this.transform.position = currentPosition;

        // This changes the direction that the hair is going to point in, when we are not inputting any movements then we subtract the gravity vector
        // The gravity vector just being (0, -1, 0)
        displacementDirection -= direction * Time.deltaTime * 10.0f;
        if (direction == Vector3.zero)
            displacementDirection.y -= 10.0f * Time.deltaTime;

        if (displacementDirection.magnitude > 1) displacementDirection.Normalize();

        // In order to avoid setting this variable on every single shell's material instance, we instead set this is as a global shader variable
        // That every shader will have access to, which sounds bad, because it kind of is, but just be aware of your global variable names and it's not a big deal.
        // Regardless, setting the variable one time instead of 256 times is just better.

        // Generally it is bad practice to update statics that do not need to be updated every frame
        // You can see the performance difference between updating 256 shells of statics by disabling the updateStatics parameter in the script
        // So it obviously matters at the extreme ends, but something above like setting the directional vector each frame is not going to make an insane diff
        // You will see in my other shaders and scripts that I do not always do this, because I'm lazy, but it's best practice to not update what doesn't need to be
        // updated.
        if (updateStatics) {
            for (int i = 0; i < shellCount; ++i) {
                shellMaterials[i].SetInt("_ShellCount", shellCount);
                shellMaterials[i].SetInt("_ShellIndex", i);
                shellMaterials[i].SetFloat("_ShellLength", shellLength);
                shellMaterials[i].SetFloat("_Density", density);
                shellMaterials[i].SetFloat("_Thickness", thickness);
                shellMaterials[i].SetFloat("_Attenuation", occlusionAttenuation);
                shellMaterials[i].SetFloat("_ShellDistanceAttenuation", distanceAttenuation);
                shellMaterials[i].SetFloat("_Curvature", curvature);
                shellMaterials[i].SetFloat("_DisplacementStrength", displacementStrength);
                shellMaterials[i].SetFloat("_OcclusionBias", occlusionBias);
                shellMaterials[i].SetFloat("_NoiseMin", noiseMin);
                shellMaterials[i].SetFloat("_NoiseMax", noiseMax);
                shellMaterials[i].SetVector("_ShellColor", shellColor);
                shellMaterials[i].SetVector("_ShellDirection", displacementDirection);
                shellMaterials[i].SetVector("_LightDir", -light.forward);
            }
        }
    }

    void OnDisable() {
        for (int i = 0; i < shells.Length; ++i) {
            Destroy(shells[i]);
        }

        shells = null;
    }
}