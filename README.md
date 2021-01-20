# Microglia Morphology Analysis Plugin

This is the repo where development on turning the 'MicrogliaMorphologyAnalysis.ijm' script file present in https://github.com/BrainEnergyLab/Inflammation-Index into a plugin to improve reliability and useability is being done.

This plugin will be available as a .jar file to drop into the plugins folder of a Fiji installation. A .py file will also need to be added to the plugins folder to facilitate the Sholl analysis of cell masks.

The functions in this plugin will only function as part of a pipeline and will require a particular folder structure to work. This is outlined in the appropriate documentation at https://github.com/BrainEnergyLab/Inflammation-Index.

Next iterations of this plugin will introduce functions that can be applied outside of the pipeline on single images to facilitate users building their own pipelines using the image cleaning, cell detection, and mask quantification features available.

This repo is based on a repo designed to convert a collection of ImageJ script .ijm files into a plugin (https://github.com/imagej/example-script-collection). The README for that forked repo is now in the Legacy readme.md file.

