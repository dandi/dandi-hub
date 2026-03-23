# Dandi Docker Images

This folder contains the Dockerfile to build the MATLAB image for Dandi:

* `Dockerfile.matlab` provides a Nebari compatible jupyter environment with MATLAB(R) installed. This image requires you to bring your own licence.

## MATLAB Docker Image

The MATLAB Docker image relies on the [MATLAB Integration for Jupyter in a Docker Container](https://github.com/mathworks-ref-arch/matlab-integration-for-jupyter).
It is shipped with [MATLAB-proxy](https://github.com/mathworks/matlab-proxy) which enables communication with MATLAB from a web-browser, and with [MATLAB-proxy-jupyter](https://github.com/mathworks/jupyter-matlab-proxy) which adds MATLAB integration for Jupyter.

This Dockerfile includes the following package, including platform products, toolbox products, and support packages from MathWorks® obtained via MATLAB Package Manager [(MPM)](https://www.mathworks.com/products/mpm.html), and additional add-on packages obtained from File Exchange and/or GitHub®

| # | Package | Source | Current Version | Projected Update Strategy |
| --- | :--- | :---- | :--- | :--- |
| 1 | MATLAB | MPM | R2025b | Penultimate MathWorks Release |
| 2 | Bioinformatics Toolbox | MPM | R2025b | Penultimate MathWorks Release | 
| 3 | Computer Vision Toolbpx | MPM | R2025b | Penultimate MathWorks Release | 
| 4 | Curve Fitting Toolbox | MPM | R2025b | Penultimate MathWorks Release | 
| 5 | Deep Learning Toolbox | MPM | R2025b | Penultimate MathWorks Release | 
| 6 | Econometrics Toolbox | MPM | R2025b | Penultimate MathWorks Release | 
| 7 | Financial Toolbox | MPM | R2025b | Penultimate MathWorks Release | 
| 8 | Image Processing Toolbox | MPM | R2025b | Penultimate MathWorks Release| 
| 9 | Parallel Computing Toolbox | MPM | R2025b | Penultimate MathWorks Release |
| 10 | Signal Processing Toolbox | MPM | R2025b | Penultimate MathWorks Release |
| 11 | Statistics & Machine Learning Toolbox | MPM | R2025b | Penultimate MathWorks Release |
| 12 | Wavelet Toolbox | MPM | R2025b | Penultimate MathWorks Release |
| 13 | Deep Learning Toolbox Converter for TensorFlow Models | MPM | R2025b | Penultimate MathWorks Release
| 14 | [MatNWB](https://github.com/NeurodataWithoutBorders/matnwb) | GitHub | v2.9.0 | Latest Release |
| 15 | [Brain Observatory Toolbox](https://github.com/MATLAB-Community-Toolboxes-at-INCF/Brain-Observatory-Toolbox) | GitHub | v0.9.4.2 | Latest Release |
| 16 | [Deep Interpolation Toolbox](https://github.com/MATLAB-Community-Toolboxes-at-INCF/DeepInterpolation-MATLAB) | GitHub | v0.9.1 | Latest Release |
| 17 | [EXTRACT](https://github.com/schnitzer-lab/EXTRACT-public) | GitHub | Latest Commit | Latest Commit |
| 18 | [CIATAH](https://github.com/bahanonu/ciatah) | GitHub | Latest Commit | Latest Commit |
| 19 | [Example Live Scripts](https://github.com/MATLAB-Community-Toolboxes-at-INCF/example-live-scripts) | GitHub | Latest Commit | Latest Commit |

_Note:_ `EXTRACT` and `CIATAH` pull the latest commit from the git repository at Docker image build time. `Example Live Scripts` however pulls the latest commit from the git repository **the first time you start a MATLAB session** and only this first time. If you already have pulled a version and need to update to a more updated latest commit from the git repository open a console, then:

```bash
cd example-live-scripts
git pull
```

If you have modified the existing examples, you might have to solve conflicts manually.

### How to Build

Building the MATLAB Docker image is straight forward.
The following lines consider that you already cloned the repository and that you are positioned in the `docker` folder in the cloned repository on your file system.

```bash
docker build -t dandi-matlab - < Dockerfile.matlab
```

This will build the image tagging it as `dandi-matlab`.

### How to Run

Running a container for the built image requires that a port is passed to the command line to tell the container which internal port needs to be exposed and on which port to map it in the host system.

```bash
docker run -p 8888:8888 dandi-matlab:latest
```

This command considers the exposition of port `8888` and maps it to the port `8888` in the host.
The syntax of the option is `-p [host port]:[container port]`.
The port to expose in the container is always `8888`, but the host port can be changed to what is the best for your system.

After the container started, you can check the logs and you will see lines giving you the address you can open in your web browser to start the Jupyter instance.

```
To access the server, open this file in a browser:
    file:///home/jovyan/.local/share/jupyter/runtime/jpserver-6-open.html
Or copy and paste one of these URLs:
    http://78bd0f342a19:8888/lab?token=6bf3ad4d468ab3532fab610f5ff28dcf27b1b60300ec8e0c
 or http://127.0.0.1:8888/lab?token=6bf3ad4d468ab3532fab610f5ff28dcf27b1b60300ec8e0c
```

To open locally the Jupyter, copy/paste the `127.0.0.1:8888/xxxxx` address in your browser.

CAUTION: If you changed the port on which will be mapped the internal container port, do not forget to change it also in the address you copy/paste from the logs.

### Closing your Session

Be careful while closing your session.
If you don't close the session properly prior to stop your container, _i.e_: closing the MATLAB session and disconnecting yourself, there is chances that the MATLAB licencing system sees yourself as still connected and you'll have to wait the timeout of the session to be able to log/connect again after restarting the container.

To properly close your session, click on the `MATLAB Jupyter Setting` button which appears above the MATLAB top bar.
From there, if you really want to close your session, clic on "Stop MATLAB Session", and if you really want to stop your Jupyter session, clic on "Sign Out".

### Add new Add-Ons

By default, the `Dockerfile.matlab` image is shipped with two addons already installed and accessible from MATLAB.
You can easily add/remove addons by changing some lines in the Dockerfile: the addons links to download/install are defined by the `ARG ADDONS` variable.

CAUTION: The download links have to be release links towards `.zip` files.

#### How the Add-On Registration is Working

The add-ons registration is actually performed in two steps happening at two differents times: at "docker image construction" time, and at MATLAB startup time.

During the docker image construction, all add-ons referenced by the `ADDONS` variable in the Dockerfile are downloaded and extracted in a specific folder: `/opt/extras/dandi`.

At startup-time, this folder is automatically scanned by MATLAB and all downloaded add-ons are added to the "path" of MATLAB.
The code responsible for the auto-scan of the add-ons folder is directly injected in the `startup.m` file during the docker image construction.
If some add-ons require extra actions after being installed/added to the path, you can modify these lines to add extra action before the `clear`:

```dockerfile
# Generate MATLAB startup script
RUN echo -e "\n\
% Set the number of workers for 'Processes' to 5\n\
cluster = parcluster('Processes'); \n\
cluster.NumWorkers = 5; \n\
saveProfile(cluster); \n\
 \n\
% Copy the live-example folder \n\
homedirExamples = strcat(getenv('HOME'), '/example-live-scripts') \n\
if not(isfolder(homedirExamples)) \n\
    repo = gitclone('https://github.com/MATLAB-Community-Toolboxes-at-INCF/example-live-scripts', homedirExamples, Depth=1); \n\
end \n\
% Add the example library to the path \n\
addpath(homedirExamples); \n\
% Add the addons to the path \n\
addons = dir('${ADDONS_DIR}'); \n\
addons = setdiff({addons([addons.isdir]).name}, {'.', '..'}); \n\
for addon_idx = 1:numel(addons) \n\
    addpath(genpath(strcat('${ADDONS_DIR}/', addons{addon_idx}))); \n\
end \n\
% generateCore();  % Generate the most recent nwb-schema \n\
% ciapkg.io.loadDependencies('guiEnabled', 0);  % Load dependencies for CIAtah \n\
% ADD HERE EXTRA ACTIONS FOR YOUR ADD-ON IF REQUIRED! \n\ <-- Starting here
clear" >> ${STARTUP_SCRIPT}
```

### Customize your Container

You can customize some parameter of your container changing some variables in the `Dockerfile.matlab`.

You can impact those parameters:

`ADDONS_DIR`:
This variable defines where the add-ons must be downloaded/extracted and what will be the folder scanned by MATLAB at startup time.
If you change this folder, the Jupyter user needs to have read/write access to it. This comes from a specificity of `matnwb` which requires the execution of some extra actions for its activation.

`ADDONS_RELEASE`:
This variable defines the list of add-ons to download and install. You can add as much add-ons as you want as long as they are compatible with MATLAB-R25.

`ADDONS_LATEST`:
This variable defines the list of add-ons to download and install directly from the lastest version identified in the github repository.
