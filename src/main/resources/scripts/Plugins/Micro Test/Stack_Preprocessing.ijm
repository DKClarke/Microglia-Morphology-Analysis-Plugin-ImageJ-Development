function findFileWithFormat(folder, fileFormat) {

	//We get the list of files in the folder
	fileList = getFileList(folder);
	
	//Create an array to store our locations and a counter for how many files we've found
	storeIt = newArray(1);
	storeIt[0] = 'none';
	count = 0;
	for(i=0; i<fileList.length; i++) {
		if(endsWith(toLowerCase(fileList[i]), fileFormat)) {
			//Create a variable that tells us which file has the format we're looking for
			fileLocation = folder + fileList[i]; 
			
			//If we're onto our second location, create a new array to tack onto storeIt that we then
			//fill with the new location
			if(count >0) {
				appendArray = newArray(1);
				storeIt = Array.concat(storeIt, appendArray);
			}
			
			//Store the location and increase the count
			storeIt[count] = fileLocation;
			count += 1;
		}
	}

	if(storeIt[0] == 'none') {
		exit("No file found");
	} else {
		return storeIt;
	}

}

function parseIniValues(iniStrings, iniToOpen) {
		
	//We open the ini file as a string
	iniText = File.openAsString(iniToOpen);	
	
	iniValues = newArray(iniStrings.length);

	//Looping through the values we want to grab
	for(i=0; i<iniStrings.length; i++) {

		//We create a start point that is the index of our iniStrings + the length of the string
		startPoint = indexOf(iniText, iniStrings[i])+lengthOf(iniStrings[i]);

		//Get a substring that starts at our startPoint i.e. where the numbers of our current string start
		checkString = substring(iniText, startPoint);

		//For each character, if it isn't numeric add 1 to the hitCount and if we hit
		//two consecutive non-numerics, go back to pull out the values and store them
		hitCount = 0;
		for(j=0; j<lengthOf(checkString); j++) {
			if(charCodeAt(checkString, j) < 48 || charCodeAt(checkString, j) > 57) {
				hitCount = hitCount + 1;
				if(hitCount == 2) {
					realString = substring(checkString, 0, j);
					break;
				}
			}
		}

		//Parse our values
		iniValues[i] = parseFloat(realString);
	}

	return iniValues;

}

//This is a function to retrieve the data from the ini file. The ini file contains calibration information for the 
//entire experiment that we use to calibrate our images. iniFolder is the folder within which the ini file is located, 
//and iniValues is an array we pass into the function that we fill with calibration values before returning it	
function getIniData(iniFolder, iniStrings) {

	//Find our ini file
	iniLocations = findFileWithFormat(iniFolder, "ini");
	if(iniLocations.length > 1) {
		exit("More than 1 ini file found, exiting plugin");
	} else {
		print(".ini file found at", iniLocations[0]);
		iniToOpen = iniLocations[0];
	}

	iniValues = parseIniValues(iniStrings, iniToOpen);
		
	return iniValues;
}

function getWorkingAndStorageDirectories(){

    Dialog.create("Pick Directory");
    Dialog.addMessage("Choose morphology analysis working directory");
    Dialog.show();

    setOption("JFileChooser", true);
    workingDirectory = getDirectory("Choose morphology analysis working directory");

    Dialog.create("Pick Directory");
    Dialog.addMessage("Choose the image storage directory");
    Dialog.show();
    //Get the parent 2P directory i.e. where all the raw 2P images are stored
    imageStorage = getDirectory("Choose the image storage directory");
    setOption("JFileChooser", false);

    //Here we create an array to store the full name of the directories we'll be 
    //working with within our morphology processing directory
    directories=newArray(workingDirectory+"Input" + File.separator, 
						workingDirectory+"Output" + File.separator, 
						workingDirectory+"Done" + File.separator,
						imageStorage);
    //[0] is input, [1] is output, [2] is done, [3] is image storage

    directoriesNames = newArray('Input', 'Output', 'Done', 'Image Storage');
    for (i = 0; i < directories.length; i++) {
		print('Directories', directoriesNames[i], ':',  directories[i]);
    }

    images_in_storage = listFilesAndFilesSubDirectories(directories[3], '.tif');
    if(images_in_storage.length == 0) {
    	exit('No .tif images in image storage, exiting plugin');
    }

    return directories;
}

function makeDirectories(directories) {

    //Here we make our working directories by looping through our folder names, 
    //concatenating them to our main parent directory
    //and making them if they don't already exist
    for(i=0; i<directories.length; i++) {
        if(File.exists(directories[i])==0) {
            File.makeDirectory(directories[i]);
            print('Made directory ', directories[i]);
        } else {
        	print('Directory', directories[i], 'already exists');
        }
    }
}

//This function clears the results table if it exists, clears the roimanager, and closes 
//all open images - useful for quickly clearing the workspace
function Housekeeping() {
	
	if (isOpen("Results")) {
		run("Clear Results");
	}
	if(roiManager("count")>0) {
		roiManager("deselect");
		roiManager("delete");
	}
	if(nImages>0) {
		run("Close All");
	}
}

function getPreprocessingInputs() {

	//Store the defaults and strings for the input we require
    inputs_array = newArray(1, 3, false, 'Morphology');
    inputs_labels = newArray("How many frames per Z plane to average over for the final Z plane image?",
    	"How many frames do you want to include in the average projection of least blurry frames?",
    	"Manually select frames to keep from images that failed automated selection QA?",
    	"String to Search For in the Image Storage Directory", "Morphology");

    //Ask the user how many frames they want to retain for motion correction and how many frames they want to use
    //to make the average projection to compare other frames to (lapFrames) - also ask if the user would rather select
    //the frames to use manually 
    Dialog.create("Info for each section");
	for (i = 0; i < inputs_array.length; i++) {
		if(i == 0 || i == 1){
			Dialog.addNumber(inputs_labels[i], inputs_array[i]);
		} else if (i==2) {
			Dialog.addCheckbox(inputs_labels[i], inputs_array[i]);
		} else if (i == 3) {
			Dialog.addString(inputs_labels[i], inputs_array[i]);
		}
	}
    Dialog.show();

	//Overwrite our defaults with the input values, and apply exit conditions and print
	for (i = 0; i < inputs_array.length; i++) {
		if(i == 0 || i == 1){
			inputs_array[i] = Dialog.getNumber();
			if(inputs_array[i] == 0) {
				exit("Specified an input as zero - this is not permitted");
			}
		} else if (i==2) {
			inputs_array[i] = Dialog.getCheckbox();
		} else if (i == 3) {
			inputs_array[i] = Dialog.getString();
		}
		print(inputs_labels[i], ':', inputs_array[i]);
	}

    return inputs_array;
    //[0] is differenceFrames, [1] is blurFrames, [2] is manSelect, [3] is stringToFind

}

//This function takes an input array, and removes all the 0's in it, outputting 
//it as the output array which must be passed in as an argument
function removeZeros(inputArray) {

	//Loop through the input array, if the value isn't a 0, we place that in our 
	//output array (which should be of length 1) before then concatenating an 
	//array of length 1 to it to add another location to store another non-zero 
	//value from the input array
    output = newArray(1);
	count = 0;
	for(i=0; i<inputArray.length; i++) {
		if(inputArray[i]!=0) {
			currentIndex=output.length-1;
			if(count > 0) {
				appendArray = newArray(1);
				output = Array.concat(output, appendArray);
			}
			output[count] = inputArray[i];
			count += 1;
		}
	}

	return output;
}

//Function finds all files that contain "substring" in the path "directoryname" 
//"fileLocations" is an array that is passed in to fill with paths that contain substring
function listFilesAndFilesSubDirectories(directoryName, subString) {

	//Get the list of files in the directory
	listOfFiles = getFileList(directoryName);

	//an array to add onto our fileLocations array to extend it so we can keep adding to it
	arrayToConcat = newArray(1);
    fileLocations = newArray(1);

	//Loop through the files in the file list
	for (i=0; i<listOfFiles.length; i++) {

		//Create a string of the full path name
		fullPath = directoryName+listOfFiles[i];
		
		//If the file we're checking is a file and not a directory and if it  contains the substring we're 
		//interested in within its full path we check  against the absolute path of our file in lower case on both counts
		if (File.isDirectory(fullPath)==0 && indexOf(toLowerCase(fullPath), toLowerCase(subString))>-1) {
			
			//We store the full path in the output fileLocations at the latest index 
			//(end of the array) and add an extra bit onto the Array so we can keep filling it
			fileLocations = Array.concat(fileLocations, arrayToConcat);
			currentIndex=fileLocations.length-1;
			fileLocations[currentIndex] = fullPath;

		//If the file we're checking is a directory, then we run the whole thing on that directory
		} else if (File.isDirectory(fullPath)==1) {

			//Create a new array to fill whilst we run on this directory and at the end add it onyo the fileLocations array 
			tempArray = listFilesAndFilesSubDirectories(fullPath, subString);
			fileLocations = Array.concat(fileLocations, tempArray);     
			
		}
	}

	//Create a new array that we fill with all non zero values of fileLocations
	output = removeZeros(fileLocations);

	//Then return the output array
	return output;
	
}

function parseAnimalTreatmentIDsFromStoragePath(imagePathInStorage) {

		//Here we take the location of the file that is a microglia morphology 
        //image, and we split up parts of the file name and store them in the 
        //parentArray for easier access where index [0] contains the whole string 
        //of image location, and each subsequent index is the parent directory of 
        //the previous index
        parentArray=newArray(4);
        parentArray[0] = imagePathInStorage;
        for(i1=0; i1<(parentArray.length-1); i1++){
            parentArray[i1+1] = File.getParent(parentArray[i1]);
        }
		//[0] is the full path, [1] is the treatment name, [2] is the animal name,
		//and [3] is the storage directory

		return parentArray;

}

function moveImageToInput(fileLocations, directories, appendWith){

    //Loop through all matching files
    for(i=0; i<fileLocations.length; i++) {

        imageLabels = parseAnimalTreatmentIDsFromStoragePath(fileLocations[i]);
		//[0] is the full path, [1] is the treatment name, [2] is the animal name,
		//and [3] is the storage directory
    
        //Here we create a name to save the image as based on the names in the last 2
        //directories of our image location and we add " Microglia Morphology" on 
        //to the end of it
        saveName = File.getName(imageLabels[2]) + " " + File.getName(imageLabels[1]) + " " + appendWith;

        //If this file is already saved in our input directory, or in our done 
        //directory, then we ignore it, but if it isn't we proceed
        if((File.exists(directories[0] + saveName + ".tif")==0 && File.exists(directories[2] + saveName + ".tif")==0)) {
                    
            //Here copy the image to the input folder with the saveName
            File.copy(fileLocations[i], directories[0] + saveName + ".tif");
            print(saveName, 'copied to',  directories[0]);
        
        } else {
        	print(saveName, 'already in', directories[0], 'or in', directories[2]);
        }
    }

}

function getManualFlaggedImages(imageName, autoProcessed, autoPassedQA, manualProcessed) {

	print("Retrieving image IDs to manually select frames for");

	//If an image has a manual flag or is set to be ignored, 
	//flag it's image List values with a 0 then remove
	for(currImage = 0; currImage<autoProcessed.length; currImage++) {
		
		//If the image has previously been automatically processed
		if(autoProcessed[currImage] == 1) {
			
			//If the image failed QA after being automatically processed
			if(autoPassedQA[currImage] == 'fail') {

				//If we haven't manually processed this image
				if(manualProcessed[currImage] == 0) {

					imageName[currImage] = 0;

				}
			}
		}
	}
	imagesForMan = removeZeros(imageName);

	//Get the file name of the manually flagged images
	if(imagesForMan.length != 0) {
		for(currImage = 0; currImage<imagesForMan.length; currImage++) {
			imagesForMan[currImage] = File.getName(imagesForMan[currImage]);
		}
	} else {
		print("No image IDs to be manually processed");
		imagesForMan = newArray('false');
	}

	return imagesForMan;

}

//"OutputArray" is an array in which we store the output of this function
//InputName is a string file path of an image generated by this macro
//Function cuts up the file path of the inputName into different segments that
//contain different bits of info i.e. info about the animal and 
//timepoint that we store at index [0] in the array, the timepoint only at [1]
//the animal only at [2] and finally the file name without the .tif on the end that we store at [3]
function getAnimalTimepointInfo(inputName, appendWith) {
  
  outputArray = newArray(4);

  //For some reason we need to convert these strings to strings else the function doesn't work
  outputArray[0] = File.getName(substring(inputName, 0, indexOf(inputName, appendWith)));
  outputArray[1] = toLowerCase(substring(outputArray[0], indexOf(outputArray[0], " ")+1));
  outputArray[2] = toLowerCase(substring(outputArray[0], 0, indexOf(outputArray[0], " ")));
  outputArray[3] = File.getNameWithoutExtension(inputName);

  return outputArray;

}

function openAndGetImageTimepoints(imagePath, calibrationValues, appendWith) {

    open(imagePath);
            
    //Get out the animal name info - animal and 
    //timepoint that we store at index [0] in the array, the timepoint only at [1]
    //the animal only at [2] and finally the file name without the .tif on the end
    //that we store at [3]
    imageNames = getAnimalTimepointInfo(imagePath, appendWith);
    print(imageNames[3] + " opened");

	//Calculate the number of timepoints in the image by multiplying frames per plane * number of plans, and divide
	//that by the number of slices in the image
	selectWindow(File.getName(imagePath));
    timepoints = (calibrationValues[3] * calibrationValues[4])/nSlices;

    return timepoints;

}

function formatManualSelectionImage(imagePath, timepoints) {
   
   //Convert the image to 8-bit, then adjust the contrast across all slices 
    //to normalise brightness to that of the top slice in the image
	selectWindow(File.getName(imagePath));
	slices = nSlices;
    print("Converting to 8-bit");
    run("8-bit");

    //Here we reorder our input image so that the slices are in the right structure for motion artefact removal
    print("Reordering for manual frame selection");
    run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+timepoints+" frames="+slices+" display=Color");
    run("Hyperstack to Stack");
    run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+slices+" frames="+timepoints+" display=Color");

}

function getArrayOneToMaxValue(maxValue) {

    //This makes an array with which is the length of the number of
	//Z we have per timepoint times the number of frames per Z (i.e., every slice in the stack)
	//We do this +1, then slice it, so that we get an array of the same length as our stack, starting
	//at a value of 1
    imageNumberArray = Array.getSequence(maxValue+1); 
    imageNumberArray = Array.slice(imageNumberArray, 1, imageNumberArray.length); 


    return imageNumberArray;

}

function makeZPlaneSubstack(framesPerPlan, zPlane, parentImage) {

		startFrame = (framesPerPlane * (zPlane - 1)) + 1;
		endFrame = (framesPerPlane * zPlane);

    	//Here we create substacks from our input image - one substack 
        //corresponding to all the frames at one Z point
        subName="Substack ("+startFrame+"-"+endFrame+")";
        selectWindow(parentImage);
        print(startFrame+"-"+endFrame);
        run("Make Substack...", " slices="+startFrame+"-"+endFrame+"");
        rename(subName);

        return subName;

}

function selectFramesManually(noFramesToSelect, imageName) {
    
    selectWindow(imageName);
    subSlices = nSlices;
	
    //Create an array to store which of the current substack slices we're keeping - fill with zeros
    framesToKeep = newArray(subSlices);
    framesToKeep = Array.fill(framesToKeep, 0);

    setOption("AutoContrast", true);

    //Looping through the number of frames the user selected to keep, ask the user to
    //scroll to a frame to retain, the index of this frame in framesToKeep is then set to 1
    for(currFrame=0; currFrame < noFramesToSelect; currFrame++) {
            
        setBatchMode("Exit and Display");
        run("Tile");
        selectWindow(imageName);
        waitForUser("Scroll onto the frame to retain on the image labelled 'Substack etc'");
        setBatchMode(true);
        keptSlice = getSliceNumber();
        print("Slice selected: ", keptSlice);
        print("If selecting more, select a different one");

        framesToKeep[(keptSlice-1)] = 1;
            
    }

	setOption("AutoContrast", false);

    return outputArray;
}

function populateAndSaveSlicesToUseFile(slicesToUseFile, arrayOfChosenSlices) {

	tableName = File.getNameWithoutExtension(slicesToUseFile);
	
	//Save our array in a csv file so we can read this in later
	Table.create(tableName);
	selectWindow(tableName);
	Table.setColumn("Slices", arrayOfChosenSlices);
	
	//If the output directory for the input image hasn't already been made, make it
	directoryToMake = newArray(File.getDirectory(slicesToUseFile));
	makeDirectories(directoryToMake);

	//Save our table
	Table.save(slicesToUseFile);

	actualTableName = Table.title;

	//Since we save it every time, we have to rename it to get rid of the .csv 
	if(actualTableName != tableName) {
		Table.rename(actualTableName,tableName);
	}
		
	selectWindow(tableName);
	run("Close");

}

function manuallyApproveZPlanes(framesPerPlane, zPlane, renameAs, framesToKeep) {

	subName = makeZPlaneSubstack(framesPerPlane, zPlane, renameAs);

	manualFramesToKeep = selectFramesManually(framesToKeep, subName);

	selectWindow(subName);
	run("Close");

	return manualFramesToKeep;

}


function addPreviousFramesToManualSelection(currentStep, framesPerStep, framesArray) {
			
	framesBeforeThisStep = (currentStep-1) * framesPerStep;
	adjustedFrameLocations = newArray(framesArray.length);
	for(currentIndex = 0; currentIndex < framesArray.length; currentIndex++) {
		adjustedFrameLocations[currentIndex] = framesArray[currentIndex] + framesBeforeThisStep;
	}

	return adjustedFrameLocations;

}

function manuallyApproveTimepoints(toOpen, currentTimepoint, iniValues, framesToKeep, renameAs) {

	//Get out the current timepoint, split it into a stack for each frame (i.e. 14 stacks of 26 slices)
	getTimepointStack(toOpen, currentTimepoint, renameAs);

	numberOfZPlanes = iniValues[3];
	framesPerPlane = iniValues[4];

	//Loop through all Z points in our image
	for(zPlane=1; zPlane<(numberOfZPlanes + 1); zPlane++) {

		zFramesToKeep = manuallyApproveZPlanes(framesPerPlane, zPlane, renameAs, framesToKeep);
		zFramesToKeepOverallPosition = addPreviousFramesToManualSelection(zPlane, framesPerPlane, zFramesToKeep);

		if(zPlane == 1) {
			finalZFrameImages = zFramesToKeepOverallPosition;
		} else {
			finalZFrameImages = Array.concat(finalZFrameImages, zFramesToKeepOverallPosition);
		}

	}

	selectWindow(renameAs);
	run("Close");

	return finalZFrameImages;

}

function manualFrameSelection(directories, manualFlaggedImages, iniValues, framesToKeep, appendWith) {

	numberOfZPlanes = iniValues[3];
	framesPerPlane = iniValues[4];
	
	//Loop through the files in the manually flagged images array
	for(i=0; i<manualFlaggedImages.length; i++) {

		proceed = false;
		
		//If we're doing manual processing and we don't have a list of slices to use for an 
		//image, but the image exists, proceed
		slicesToUseFile = directories[1] + manualFlaggedImages[i] + "/Slices To Use.csv";
    	toOpen = directories[0] + manualFlaggedImages[i] + ".tif";
		if(File.exists(slicesToUseFile)==0 && File.exists(toOpen)==1) {
			proceed = true;	
		}

        if(proceed = true) {

            print("Manually selecting frames for", File.getNameWithoutExtension(toOpen));
            
			//Open the image, get ini values, use to calculate the numbber of timepoints and values
			//we need to format the stack for manual selection
            timepoints = openAndGetImageTimepoints(toOpen, iniValues, appendWith);

			//Format the image for manual selection
			formatManualSelectionImage(toOpen, timepoints);

			//Reorder each individual timepoint stack in Z so that any out of position slices are positioned correctly 
			//for motion artifact detection and removal
            //Go through each timepoint
            for(currentTimepoint=1; currentTimepoint<timepoints+1; k++) {	
				
				renameAs = "Timepoint"
				timepointFramestoKeep = manuallyApproveTimepoints(toOpen, currentTimepoint, iniValues, framesToKeep, renameAs);

				framesPerTimepoint = framesPerPlane*numberOfZPlanes
				timepointFramesToKeepOverallPosition = addPreviousFramesToManualSelection(currentTimepoint, framesPerTimepoint, timepointFramestoKeep);

			}

			populateAndSaveSlicesToUseFile(slicesToUseFile, timepointFramesToKeepOverallPosition);

            Housekeeping();

        } else {

			print("Either image ", File.getNameWithoutExtension(toOpen), " doesn't exist, or it has a SlicesToUse.csv file already");

		}	

    } 

}

function manualFrameSelectionWrapper(directories, manualFlaggedImages, iniValues, framesToKeep, appendWith, manCorrect) {
	
	//If the user wants to manually select frames, and we have images eligibile for this (i.e. not being ignored from analysis or
	//already manually frames chosen
	if(manualFlaggedImages[0] != 'false' && manCorrect == 1) {

			print('Beginning manual frame selection');
			manualFrameSelection(directories, manualFlaggedImages, iniValues, framesToKeep, appendWith);

	} else if(manualFlaggedImages[0] == 'false') {

		print('No images to manually choose frames for');
		
	} else if(manCorrect == 0) {

		print('User has not chosen to manually select frames');
		
	}

}

function imagesToProcess(manualFlaggedImages, directories) {

		//For all the images in our input folder, check if they're in our manual flagged images array
		imagesInput = getFileList(directories[0]);
		for(currImage = 0; currImage < imagesInput.length; currImage++) {
			for(currManualCheck = 0; currManualCheck < manualFlaggedImages.length; currManualCheck++){

				//If they're in our manual flagged images array, and they don't have a slices to use file created for them, exclude them
				if(File.getName(imagesInput[currImage]) == manualFlaggedImages[currManualCheck] && File.exists(directories[1] + manualFlaggedImages[currManualCheck] + "/Slices To Use.csv") != 1){
					imagesInput[currImage] = 0;
					break;
				}
			}
		}

		imagesToProcessArray = removeZeros(imagesInput);

		//Return the array of images to put through processing
		return imagesToProcessArray;
}

function stackContrastAdjust(imageName) {

	//Adjust the contrast in the stack to normalise it across all Z depths and timepoints
	print("Adjusting Contrast Across Entire Stack");
	selectWindow(imageName);
	run("8-bit");
	setSlice(1);
	run("Stack Contrast Adjustment", "is");
	stackWindow = getTitle();
	selectWindow(imageName);
	run("Close");
	selectWindow(stackWindow);
	rename(imageName);
	run("8-bit");

}

function expandCanvas(imageName) {

	//Increase the canvas size of the image by 100 pixels in x and y so that 
	//when we run registration on the image, if the image drifts we don't lose
	//any of it over the edges of the canvas
	selectWindow(imageName);
	print("Expanding Image Canvas");
	getDimensions(width, height, channels, slices, frames);
	run("Canvas Size...", "width="+(width+500)+" height="+(height+500)+" position=Center zero");

}

//This function removes any elements from an input array that conatins the string '.ini' and returns it
function removeStringFromArray(fileLocations, string) {

	for (i = 0; i < fileLocations.length; i++) {
		if(indexOf(fileLocations[i], string) > -1) {
			fileLocations[i] = 0;
		}
	}

	toReturn = removeZeros(fileLocations);

	return toReturn;
	
}

function blurDetector(zPlaneWindow){

	//As a way of detection blur in our imgaes, we use a laplacian of gaussian filter on our stack,
	//https://www.pyimagesearch.com/2015/09/07/blur-detection-with-opencv/
	//https://stackoverflow.com/questions/7765810/is-there-a-way-to-detect-if-an-image-is-blurry
			
	//We register our substack before running it through the laplacian filter
	print("Detecting least blurred frames in", zPlaneWindow);
	selectWindow(zPlaneWindow);
	run("FeatureJ Laplacian", "compute smoothing=1.0");

	//Close our pre laplacian image and rename our laplacian filtered image
	selectWindow(zPlaneWindow);
	rename("toKeep");
	selectWindow(zPlaneWindow + " Laplacian");
	rename(zPlaneWindow);
	imageSlices = nSlices;

	//For each slice in the stack, store the maximum pixel value of the laplacian filtered slice
	diffArrayAll = getSliceStatistics(zPlaneWindow);
	maxArray = Array.slice(diffArrayAll, diffArrayAll.length/2);

	//Close the laplacian filtered image
	selectWindow(zPlaneWindow);
	run("Close");

	selectWindow("toKeep");
	rename(zPlaneWindow);

	return maxArray;

}

function collapseArrayValuesIntoString(array, collapseCharacter) {
	//This loop strings together the names stored in the arrayIn into a 
	//concatenated string (called strung) that can be input into the substack 
	//maker function so that we can make a substack of all kept TZ slices in
	//a single go - we input the imageNumberArrayCutoff array
	strung="";
	for(i1=0; i1<array.length; i1++) {
		
		string=toString(array[i1]);
						
		//If we're not at the end of the array, we separate our values with a 
		//comma
		if(i1<array.length-1) {
			strung += string + collapseCharacter;
	
		//Else if we are, we don't add anything to the end
		} else if (i1==array.length-1) {
			strung += string;	
		}
	
	}

	return strung;
}

function makeSubstackOfSlices(windowName, renameTo, sliceArray) {

	//This loop strings together the names stored in the arrayIn into a 
	//concatenated string (called strung) that can be input into the substack 
	//maker function so that we can make a substack of all kept TZ slices in
	//a single go - we input the imageNumberArrayCutoff array
	strung= collapseArrayValuesIntoString(sliceArray, ",");

	selectWindow(windowName);	
	run("Make Substack...", "slices=["+strung+"]");
	rename(renameTo);

}

function registerReferenceFrame(windowName) {

	run("MultiStackReg", "stack_1=["+windowName+"] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
	run("MultiStackReg", "stack_1=["+windowName+"] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Affine]");


}

//Part of motion processing, takes an array (currentStackSlices), removes zeros from it, then
//creates a string of the numbers in the array before then making a substack of these slices
//from an imagesInput[i] window, registering them if necessary, before renaming them
//according to the info in motionArtifactRemoval
function createReferenceFrame(framesFlaggedForRetention, currentSubstackWindowName, renameTo) {
	
	//Here we order then cutoff the zeros so we get a small array of the 
	//slices to be retained
	framesToRetain=removeZeros(framesFlaggedForRetention);

	makeSubstackOfSlices(currentSubstackWindowName, renameTo, framesToRetain);
					
	selectWindow(renameTo);
	newSlices = nSlices;
		
	//If the image has more than 1 slice, register it and average project it 
	//so that we get a single image for this ZT point
	if(newSlices>1){
						
		print("Registering ", currentSubstackWindowName);
		registerReferenceFrame(renameTo);
						
		selectWindow(renameTo);
		run("Z Project...", "projection=[Average Intensity]");
		selectWindow(renameTo);
		run("Close");
		selectWindow("AVG_" + renameTo);
		rename(renameTo);

	} else {
		print("Only one frame retained, no registration or averaging being applied");
	}

}

function registerToReferenceFrame(referenceFrame, zFramesWindow){

	print("Registering to reference frame");
	selectWindow(referenceFrame);
	run("Concatenate...", " title = referenceFrameAttached image1=["+referenceFrame+"] image2=["+zFramesWindow+"] image3=[-- None --]");
	selectWindow("Untitled");
	run("MultiStackReg", "stack_1=[Untitled] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
	selectWindow("Untitled");
	run("Make Substack...", "delete slices=1");
	selectWindow("Untitled");
	rename(zFramesWindow);
	selectWindow("Substack (1)");
	rename(referenceFrame);

}

function getSliceStatistics(imageName) {

	selectWindow(imageName);

	outputArray = newArray(nSlices * 2);

	for(currMetric = 0; currMetric < 2; currMetric++) {
		for(currSlice = 1; currSlice < (nSlices+1); currSlice++) {
			setSlice(currSlice);
			getRawStatistics(nPixels, mean, min, max, std, hist);
			if(currMetric == 0) {
				outputArray[currSlice-1] = mean;
			} else if (currMetric == 1) {
				outputArray[(currSlice-1) + nSlices] = max;
			}
		}
	}

	return outputArray;

}

function setToZeroIfCutoff(inputArray, framesPerPlane, rankCutoff, direction) {
	//Cutoff routine
		
	//This cutoff routine takes the measured square differences of each 
	//slice, and ranks them highest to lowest. We then select the best of 
	//the images (those with the lowest square differences). In this case we 
	//select the FramesToKeep lowest images i.e. if we want to keep 5 frames 
	//per TZ point, we keep the 5 lowest square difference frames per FZ.

	//Here we rank the array twice, this is necessary to get the ranks of 
	//the slices so that the highest sq diff value has the highest rank and 
	//vice versa
	preRankedOutput=Array.rankPositions(inputArray);
	rankedArray=Array.rankPositions(preRankedOutput);

	//For each slice in the stack, store the maximum pixel value of the laplacian filtered slice in this
	//timepoint's results
	framesToKeep = getArrayOneToMaxValue(framesPerPlane);
	for(currFrame = 0; currFrame < framesPerPlane; currFrame++) {	
		if(direction == 'below'){
			if (rankedArray[currFrame]<(rankedArray.length-rankCutoff)) {
				framesToKeep[currFrame] = 0;
			}
		} else if(direction == 'above') {
			if (rankedArray[currFrame] > rankCutoff-1) {
				framesToKeep[currFrame] = 0;
			}
		} else {
			exit("Direction argument in setToZeroIfCutoff() not specified correctly")
		}
	}

	return framesToKeep;


}

function diffDetector(referenceFrame, subName) {

	print("Detecting frames least different from reference");
	//Calculate the difference between the average projection and the stack
	imageCalculator("Difference create stack", subName, referenceFrame);
	
	//Measure the difference (mean grey value) for each slice - ideally all this code should be put into a function since it
	//is a repeat of the laplacian frame selection from earlier
	diffArrayAll = getSliceStatistics("Result of " + subName);
	meanArray = Array.slice(diffArrayAll, 0, (diffArrayAll.length/2));

	selectWindow("Result of " + subName);
	run("Close");

	selectWindow(referenceFrame);
	run("Close");

	return meanArray;

}

//Function to incorporate the reordering of Z slices in registration. Takes an 
//inputImage, then rearranges slices that are maximally layersToTest apart 
//before renaming it toRename
function zSpaceCorrection(inputImage, layersToTest, toRename) {

	//Array to store the name of output images from the spacing correction to 
	//close
	toClose = newArray("Warped", "Image", inputImage);

	//Runs the z spacing correction plugin on the input image using the 
	//layersToTest value as the maximum number of layers to check against for z 
	//positioning
	selectWindow(inputImage);
	run("Z-Spacing Correction", "input=[] type=[Image Stack] text_maximally="+layersToTest+" outer_iterations=100 outer_regularization=0.40 inner_iterations=10 inner_regularization=0.10 allow_reordering number=1 visitor=lazy similarity_method=[NCC (aligned)] scale=1.000 voxel=1.0000 voxel_0=1.0000 voxel_1=1.0000 render voxel=1.0000 voxel_0=1.0000 voxel_1=1.0000 upsample=1");

	closeImages(toClose);

	//Renames the output image to the toRename variable
	selectWindow("Z-Spacing: " + inputImage);
	rename(toRename);

	//Close the exception that is thrown by the rearranging of stacks
	selectWindow("Exception");
	run("Close");

}

function closeImages(toClose) {

	//Closes any images that are in the toClose array first by getting a list of 
	//the image titles that exist
	imageTitleList = getList("image.titles");

	//Then we loop through the titles of the images we want to close, each time 
	//also looping through the images that are open
	for(k = 0; k<toClose.length; k++) {
		for(j=0; j<imageTitleList.length; j++) {
			
			//If the title of the currently selected open image matches the one we 
			//want to close, then we close that image and terminate our search of the 
			//current toClose title in our list of images and move onto the next 
			//toClose title
			if(indexOf(imageTitleList[j], toClose[k]) == 0) {
				selectWindow(imageTitleList[j]);
				run("Close");
				break;
			}
		}
	}
}

function concatenateArrayOfImages(imageArray, collapsedName) {

	arrayOfFormattedNames = newArray(imageArray.length);
	for(currElement = 1; currElement < imageArray.length + 1; currElement++){
		arrayOfFormattedNames[currElement-1] = "image" + currElement + "=" + imageArray[currElement-1];
	}

	forConcat = collapseArrayValuesIntoString(arrayOfFormattedNames, " ");
	if(imageArray.length>1) {
		run("Concatenate...", " title = ["+collapsedName+"] "+forConcat+"");
		selectWindow("Untitled");
		rename(collapsedName);
	} else {
		selectWindow(imageArray[0]);
		rename(collapsedName);
	}


}

function formatTimepointStack(timepointStack, numberOfZPlanes, diffDetectorFrames) {

	print("Registering timepoint stack");
	run("MultiStackReg", "stack_1="+timepointStack+" action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Translation]");
	selectWindow(timepointStack);
	run("8-bit");

	print("Correcting for discrepancies in Z location");
	zSpaceCorrection(timepointStack, numberOfZPlanes, timepointStack);
	selectWindow(timepointStack);
	run("8-bit");
	run("MultiStackReg", "stack_1="+timepointStack+" action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Affine]");
	selectWindow(timepointStack);
	run("8-bit");
	print("Done");

	//If we're only keeping a single frame (which means we won't have 
	//average projected our image earlier function) then we median blur 
	//our image 
	if(diffDetectorFrames==1) {
		print("Median blurring stack given we only retained 1 frame per Z depth");
		selectWindow(timepointStack);
		run("Median 3D...", "x=1 y=1 z=1");
	}


}

function manualCreateCleanedFrame(framesPerPlane, zPlane, renameAs, manuallyChosenFrames) {

	//Here we create substacks from our input image - one substack 
	//corresponding to all the frames at one Z point
	subName = makeZPlaneSubstack(framesPerPlane, zPlane, renameAs);

	referenceFrameDiff = "diffDetectZPlane" + zPlane;
	createReferenceFrame(manuallyChosenFrames, subName, referenceFrameDiff);
	
	selectWindow(subName);
	run("Close");

	return referenceFrameDiff;

}

function autoCreateCleanedFrame(framesPerPlane, zPlane, renameAs, blurDetectorFrames, diffDetectorFrames) {

	//Here we create substacks from our input image - one substack 
	//corresponding to all the frames at one Z point
	subName = makeZPlaneSubstack(framesPerPlane, zPlane, renameAs);

	blurDetectorOutput = blurDetector(subName);
	
	framesToKeepBlur =  setToZeroIfCutoff(blurDetectorOutput, framesPerPlane, blurDetectorFrames, "below");

	referenceFrameBlur = "blurDetectZPlane" + zPlane;
	createReferenceFrame(framesToKeepBlur, subName, referenceFrameBlur);

	registerToReferenceFrame(referenceFrameBlur, subName);

	diffDetectorOutput = diffDetector(referenceFrameBlur, subName);	

	framesToKeepDiff =  setToZeroIfCutoff(diffDetectorOutput, framesPerPlane, diffDetectorFrames, "above");
	
	referenceFrameDiff = "diffDetectZPlane" + zPlane;
	createReferenceFrame(framesToKeepDiff, subName, referenceFrameDiff);
	
	selectWindow(subName);
	run("Close");

	return referenceFrameDiff;
	
}

function getTimepointStack(imagePath, currentTimepoint, renameAs) {
	
	selectWindow(File.getName(imagePath));
	
	//Get out the current timepoint, split it into a stack for each frame (i.e. 14 stacks of 26 slices)
	run("Duplicate...", "duplicate frames="+(currentTimepoint)+"");	
	selectWindow(substring(File.getName(imagePath), 0, indexOf(File.getName(imagePath), ".tif")) + "-1.tif");	
	rename(renameAs);

}


function createCleanedTimepoint(renameAs, imagePath, currentTimepoint, iniValues, blurDetectorFrames, diffDetectorFrames, manuallyChosenFrames) {

	//Get out the current timepoint, split it into a stack for each frame (i.e. 14 stacks of 26 slices)
	getTimepointStack(imagePath, currentTimepoint, renameAs);

	numberOfZPlanes = iniValues[3];
	framesPerPlane = iniValues[4];

	finalZFrameImages = newArray(numberOfZPlanes);
	//Loop through all Z points in our image
	for(zPlane=1; zPlane<(numberOfZPlanes + 1); zPlane++) {

		if(manuallyChosenFrames[0] == 'false') {
			cleanedZFrame = autoCreateCleanedFrame(framesPerPlane, zPlane, renameAs, blurDetectorFrames, diffDetectorFrames);
		} else {
			manualFramesThisZ = Array.slice(manuallyChosenFrames, (zPlane - 1) * framesPerPlane, framesPerPlane * zPlane);
			keptFrames = removeZeros(manualFramesThisZ).length;
			if(keptFrames != diffDetectorFrames) {
				print("Manually retained frames per Z: ", keptFrames);
				print("Number of frames chosen to average over: ", diffDetectorFrames);
				exit("Number of frames chosen manually doesn't equal number of frames chosen to average over in this run. See log for info");
			}
			cleanedZFrame =  manualCreateCleanedFrame(framesPerPlane, zPlane, renameAs, manualFramesThisZ);
		}

		finalZFrameImages[zPlane-1] = cleanedZFrame;

	}

	timepointStack = "timepoint" + currentTimepoint;
	concatenateArrayOfImages(finalZFrameImages, timepointStack);

	formatTimepointStack(timepointStack, numberOfZPlanes, diffDetectorFrames);

	selectWindow(renameAs);
	run("Close");

	return timepointStack;

}

function removeExtraSpace(finalStack, renameAs) {

	selectWindow(finalStack);
	run("Duplicate...", "duplicate");
	rename(finalStack + "Mask");
	setThreshold(1,255);
	run("Convert to Mask", "method=Default background=Dark");

	if(is("Inverting LUT") == true) {
		run("Invert LUT");
	}
		
	//Min project the mask showing all common pixels to get a single image that we turn into a selection, that we then impose on our concatenated stacks, turn into a proper square,
	//and then create a new image from the concatenate stacks that should contain no blank space
	selectWindow(finalStack + "Mask");
	run("Z Project...", "projection=[Max Intensity]");
	run("Create Selection");
	run("To Bounding Box");
	
	roiManager("Add");
	selectWindow(finalStack);
	roiManager("Select", 0);
	run("Duplicate...", "duplicate");
	rename("dup");

	toClose = newArray(finalStack + "Mask", finalStack, "MAX_" + finalStack + "Mask");
	closeImages(toClose);

	//As this isn't a timelapse experiment, we can close our original input 
	//image and rename our registered timepoint as the input image
	selectWindow("dup");
	rename(renameAs);
	run("Select None");

}

function calibrateImage(windowName, iniValues) {

	selectWindow(windowName);
	//using the iniTextValuesMicrons data
	getPixelSize(unit, pixelWidth, pixelHeight);
	if(unit!="um") {
		print("Calibrating image");
		selectWindow(windowName);
		getDimensions(width, height, channels, slices, frames);
		run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" unit=um pixel_width="+iniValues[0]+" pixel_height="+iniValues[1]+" voxel_depth="+iniValues[2]+"");
	} else {
		print("Image is already calibrated");
	}
	
}

function createCleanedStack(imagePath, timepoints, iniValues, blurDetectorFrames, diffDetectorFrames, manuallyChosenFrames) {

		//Reorder each individual timepoint stack in Z so that any out of position slices are positioned correctly for motion artifact detection and removal
		//Go through each timepoint
		framesPerPlane = iniValues[4];
		numberOfZPlanes = iniValues[3];
		framesPerTimepoint = framesPerPlane * numberOfZPlanes;

		finalTimepointImages = newArray(timepoints);
		for(currentTimepoint = 1; currentTimepoint < timepoints+1; currentTimepoint++) {

			renameAs = "Timepoint";
			manualFramesThisTimepoint = newArray('false');
			if(manuallyChosenFrames[0] != 'false') {
				manualFramesThisTimepoint = Array.slice(manuallyChosenFrames, (currentTimepoint - 1) * framesPerTimepoint, framesPerTimepoint * currentTimepoint);
			}

			timepointStack = createCleanedTimepoint(renameAs, imagePath, currentTimepoint, iniValues, blurDetectorFrames, diffDetectorFrames, manualFramesThisTimepoint);
			finalTimepointImages[currentTimepoint-1] = timepointStack;

		}

		finalStack = "outputStack";
		concatenateArrayOfImages(finalTimepointImages, finalStack);

		//Close the original input image and concatenate all the registered timepoint images
		selectWindow(File.getName(imagePath));
		run("Close");

		outputImageName = File.getName(imagePath);
		removeExtraSpace(finalStack, outputImageName);
	
		calibrateImage(outputImageName, iniValues);

}

function saveAndMoveOutputImage(imagePath, directories) {

	//If we haven't made an output directory for our input image in the output 
	//folder, we make it
	noExtension = File.getNameWithoutExtension(imagePath);
	directoryToMake = newArray(directories[1]+noExtension+"/");
	makeDirectories(directoryToMake);

	saveName =  noExtension + " processed.tif";
	selectWindow(File.getName(imagePath));
	saveLoc = directoryToMake[0] + saveName;
	saveAs("tiff", saveLoc);

	if(File.exists(directories[2]+imagesToProcessArray[currImage])) {
		print("Image already in done folder");
	} else {
		wasMoved = File.rename(directories[0]+imagesToProcessArray[currImage], directories[2]+imagesToProcessArray[currImage]);
		
		if(wasMoved == 0) {
			print("Issue with moving image to done folder");
		} else {
			print("Image moved from input to Done");
		}
	}

	selectWindow(saveName);
	run("Close");

}

function getTableColumn(fileLoc, colName) {

	open(fileLoc);
	tableName = Table.title;
	selectWindow(tableName);

	outputArray = Table.getColumn(colName);

	selectWindow(tableName);
	run("Close");

	return outputArray;

}


function createProcessedImageStacks(imagesToProcessArray, directories, iniValues, preProcStringToFind, blurDetectorFrames, diffDetectorFrames) {

	if(imagesToProcessArray[0] != 0) {

		for(currImage = 0; currImage<imagesToProcessArray.length; currImage++) {
			
			print("Creating cleaned stack for ", imagesToProcessArray[currImage]);
			imagePath = directories[0] + imagesToProcessArray[currImage];
			timepoints =  openAndGetImageTimepoints(imagePath, iniValues, preProcStringToFind);
			
			stackContrastAdjust(imagesToProcessArray[currImage]);
			
			expandCanvas(imagesToProcessArray[currImage]);
	
			slicesToUseFile = directories[1] + imagesToProcessArray[currImage] + "/Slices To Use.csv";
			manuallyChosenFrames = newArray('false');
			if(File.exists(slicesToUseFile) == 1) {
				print("Using manually chosen frames to create processed stack for", imagesToProcessArray[currImage]);
				manuallyChosenFrames = getTableColumn(slicesToUseFile, "Slices");
			} else {
				print("Automatically choosing frames to create processed stack for", imagesToProcessArray[currImage]);
			}	
		
			createCleanedStack(imagePath, timepoints, iniValues, blurDetectorFrames, diffDetectorFrames, manuallyChosenFrames);
		
			saveAndMoveOutputImage(imagePath, directories);
	
			print("Image processing for ", imagesToProcessArray[currImage], " complete");
			
		}
	
	} else {
		print("No images to process");
	}

}

function appendIfNew(currentArray, checkInArray, arrayToUpdate, arrayToUpdateWith) {

	//For each element in our array
	for(currElement = 0; currElement < currentArray.length; currElement++) {
		elementFound = false;

		//Check in the other arrays
		for(checkAgainst = 0; checkAgainst < checkInArray.length; checkAgainst ++) {

			//If one of the images we just QAd is in the existing table, we update the kept
			//and manualFlag values for that image
			if(currentArray[currElement] == checkInArray[checkAginst]) {
				arrayToUpdate[checkAgainst] = arrayToUpdateWith[currElement];
				elementFound = true;
				break;
			}
		}

		//If the image we QAd wasn't in the existing table, append this to the output from the
		//existing table
		if(elementFound == false) {
			arrayToUpdate = Array.concat(arrayToUpdate, newArray(arrayToUpdateWith[currElement]));
		}
	}

	return arrayToUpdate;

}

function updateImagesToUseArray(tableLoc, colName, checkArray, checkAgainst, fillWith) {

	//Retrieve columns from our images to use table telling us what stage our images are at
	currentArray = getTableColumn(tableLoc, colName);
	currentArrayToFill = newArray(checkAgainst.length);
	Array.fill(currentArrayToFill, fillWith);
	currentArray = appendIfNew(checkAgainst, checkArray, currentArray, currentArrayToFill);

}

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)

//Loop through our working directories and make them if they don't already exist
makeDirectories(Array.slice(directories, 0, 3));

//Here we set the macro into batch mode and run the housekeeping function which 
//clears the roimanager, closes all open windows, and clears the results table
setBatchMode(true);
Housekeeping();

//Ask the user for inputs on frames to keep, frames to use for the laplacian blur detector, whether to
//manually correct frames, and the string to ID morphology images
inputs_array = getPreprocessingInputs();
diffDetectorFrames = inputs_array[0];
blurDetectorFrames = inputs_array[1];
manCorrect = inputs_array[2];
preProcStringToFind = inputs_array[3];

//Here we run the listFilesAndFilesSubDirectories function on our parent 2P 
//raw data location looking for locations that are labelled with the user indicated string 
//i.e. we find our morphology images
fileLocationsRaw = listFilesAndFilesSubDirectories(directories[3], preProcStringToFind);

//Remove ini files
fileLocations = removeStringFromArray(fileLocationsRaw, '.ini');

//For each image in our image storage location, copy it into our input directory if it isn't already
//in there (and isn't in the done folder either) and append the saved images with the preProcStringToFind
moveImageToInput(fileLocations, directories, preProcStringToFind);

//Now we get out the list of files in our input folder 
//once we've gone through all the microglia morphology images in our image storage directory
imagesInput = getFileList(directories[0]);

//Point to the table where we store the status of our images in the processing pipeline
imagesToUseFile = directories[1] +  "Images to Use.csv";

//If the file exists, it means we've run at least this step before, so retrieve the stage all images are at
if(File.exists(imagesToUseFile) == 1) {

	//Retrieve columns from our images to use table telling us what stage our images are at, and if we have images in
	//imagesInput that aren't in the imageName column, we append an extra element to our arrays with the default values
	//and then do this with the image name to imageName
	imageName = getTableColumn(imagesToUseFile, "Image Name");

	autoProcessed = updateImagesToUseArray(imagesToUseFile, "Auto Processing", imageName, imagesInput, 0);

	autoPassedQA = updateImagesToUseArray(imagesToUseFile, "Auto QA Passed", imageName, imagesInput, 'not attempted');

	manualProcessed = updateImagesToUseArray(imagesToUseFile,"Manual Processing", imageName, imagesInput, 0);

	manualPassedQA = updateImagesToUseArray(imagesToUseFile, "Manual QA Passed", imageName, imagesInput, 'not attempted');

	imageName = appendIfNew(imagesInput, imageName, imageName, imagesInput);

	//Return an array of the images that are flagged for manual processing
	manualFlaggedImages = getManualFlaggedImages(imageName, autoProcessed, autoPassedQA, manualProcessed);

//If we don't have the file, we haven't run this yet
} else {

	//Set our arrays to their default values
	imageName = imagesInput;
	autoProcessed = newArray(imageName.length);
	Array.fill(autoProcessed, 0);
	autoPassedQA = newArray(imageName.length);
	Array.fill(autoPassedQA, 'not attempted');
	manualProcessed = newArray(imageName.length);
	Array.fill(manualProcessed, 0);	
	manualPassedQA = newArray(imageName.length);
	Array.fill(manualPassedQA, 'not attempted');	

	print("No image IDs to be manually processed");
	imagesForMan = newArray('false');

}

//Next steps here are to update the values in these arrays with the appropriate values depending on what processing 
//the images go through in this step, and then save them to the table

//This is an array with the strings that come just before the information we want to retrieve from the ini file.
iniTextStringsPre = newArray("x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = ");

//Array to store the values we need to calibrate our image with
iniValues =  getIniData(directories[3], iniTextStringsPre);
//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ

for (i = 0; i < iniTextStringsPre.length; i++) {
	print(iniTextStringsPre[i], iniValues[i]);
}

//For our images that are flagged for manual frame selection, ask the user to identify which frames
//to keep, then for each image, save this in a table in that images directory
manualFrameSelectionWrapper(directories, manualFlaggedImages, iniValues, diffDetectorFrames, preProcStringToFind, manCorrect);

//Get the list of images we're going to process - if we've selected to process manual images, these
//are what we process, else we do non-manually flagged images
imagesToProcessArray = imagesToProcess(manualFlaggedImages, directories);

createProcessedImageStacks(imagesToProcessArray, directories, iniValues, preProcStringToFind, blurDetectorFrames, diffDetectorFrames);

print("Image processing complete");
