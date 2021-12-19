# Microglia Morphology Analysis Plugin

This is the repo where development on the Microglia Morphology Analysis ImageJ plugin is done. Releases are available as .jar (and a single .py) files at: https://github.com/BrainEnergyLab/Inflammation-Index/.

The functions in this plugin only function as part of a pipeline and require a particular folder structure to work. This is outlined in the appropriate documentation at https://github.com/BrainEnergyLab/Inflammation-Index.

Next iterations of this plugin will introduce functions that can be applied outside of the pipeline on single images to facilitate users building their own pipelines using the image cleaning, cell detection, and mask quantification features available.

This repo is based on a repo designed to convert a collection of ImageJ script .ijm files into a plugin (https://github.com/imagej/example-script-collection). The README for that forked repo is now in the Legacy readme.md file.

To create a .jar file from this repo, run 'mvn' in the terminal. The output .jar file will be saved in the /target folder. To do this you will need to have Maven installed.

If running 'mvn' doesn't work, try 'sudo mvn' and if you are still encountering an enforcement error, try sudo mvn clean install -Denforcer.skip=true.

