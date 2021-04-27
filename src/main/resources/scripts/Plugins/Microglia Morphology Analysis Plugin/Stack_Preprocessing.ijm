function getWorkingAndStorageDirectories(){
	//Asks the user to point us to their working and image storage directories

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
	
	if(workingDirectory == imageStorage) {
		exit("Selected the same directory for 'Working' and 'Image Storage'");
	}

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

    return directories;
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
		if (File.isDirectory(fullPath)==0 && indexOf(toLowerCase(listOfFiles[i]), toLowerCase(subString))>-1) {
			
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
	output = Array.deleteValue(fileLocations, 0);

	//Then return the output array
	return output;
	
}

function getTableColumn(fileLoc, colName) {
	//Open the table at fileLoc, retrieve the colName column, if it doesn't exist,
	//return an array the size of the table filled with -1

	print("Retrieving the column ", colName, " from the table ", File.getName(fileLoc));

	if(File.exists(fileLoc) != 1) {
		exit("Table " + fileLoc + "doesn't exist");
	}

	open(fileLoc);
	tableName = Table.title;
	selectWindow(tableName);

	//If our column exists
	columns = Table.headings;
	if(indexOf(columns, colName) > -1) {
		outputArray = Table.getColumn(colName);
	
	//Else
	} else {
		outputArray = newArray(Table.size);
		Array.fill(outputArray, -1);
	}

	selectWindow(tableName);
	run("Close");

	return outputArray;

}

function findFileWithFormat(folder, fileFormat) {
	//Look for a file with the format fileFormat in folder

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
		print("No file found");
		return newArray('Not found');
	} else {
		return storeIt;
	}

}

//This is a function to retrieve the data from the ini file. The ini file contains calibration information for the 
//entire experiment that we use to calibrate our images. iniFolder is the folder within which the ini file is located, 
//and iniValues is an array we pass into the function that we fill with calibration values before returning it	
function getIniData(iniFolder, iniStrings) {

	print("Retrieving .ini data");

	//Find our ini file
	iniLocations = findFileWithFormat(iniFolder, "ini");
	if(iniLocations.length > 1) {
		exit("More than 1 ini file found, exiting plugin");
	} else if(iniLocations[0] != 'Not found') {
		print(".ini file found at", iniLocations[0]);
		iniToOpen = iniLocations[0];
	} else if(iniLocations[0] == 'Not found') {
		exit("No ini file found for calibration");
	}

	iniValues = parseIniValues(iniStrings, iniToOpen);
		
	return iniValues;
}

function parseIniValues(iniStrings, iniToOpen) {
	//Parse our ini values from the strings in the ini file
		
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
    inputs_labels = newArray("How many of the 'best' frames per Z plane do you want to include in the final Z plane image?",
    	"How many frames do you want to include in the average projection of least blurry frames per Z plane?",
    	"If you have already run the 'Stack QA' module, do you want to manually select frames to keep from images that failed automated selection QA in this run?",
    	"What string should we search for in the Image Storage directory to find stacks to process?");

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

function getManualFlaggedImages(imageName, autoProcessed, autoPassedQA, manualProcessed, manualPassedQA) {

	print("Retrieving image IDs to manually select frames for");
	imagesForMan = newArray('false');
	count = 0;

	//If an image is set to be manually processed, add it to the imagesForMan array
	for(currImage = 0; currImage<autoProcessed.length; currImage++) {
		
		//If the image has previously been automatically processed
		if(autoProcessed[currImage] == 1) {
			
			//If the image failed QA after being automatically processed
			//fail is 0, not attempted is -1, pass is 1
			if(autoPassedQA[currImage] == 0) {

				//If we haven't manually processed this image
				if(manualProcessed[currImage] == 0) {
					
					if(count > 0) {
						imagesForMan = Array.concat(imagesForMan, newArray(1));)
					}
					imagesForMan[count] = imageName[currImage];
					count++;

				}
			}
		}
	}

	//Get the file name of the manually flagged images
	if(imagesForMan[0] != 'false') {
		for(currImage = 0; currImage<imagesForMan.length; currImage++) {
			imagesForMan[currImage] = File.getName(imagesForMan[currImage]);
		}
	} else {
		print("No image IDs to be manually processed");
		imagesForMan = newArray('false');
	}

	return imagesForMan;

}

function formatManualSelectionImage(imagePath) {
   
    //Convert the image to 8-bit, then adjust the contrast across all slices 
    //to normalise brightness to that of the top slice in the image
	selectWindow(File.getName(imagePath));
	slices = nSlices;
    print("Converting to 8-bit");
    run("8-bit");

    //Here we reorder our input image so that the slices are in the right structure for motion artefact removal
    print("Reordering for manual frame selection");
    run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices=1 frames="+slices+" display=Color");
    run("Hyperstack to Stack");
    run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+slices+" frames=1 display=Color");

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

		//Compute what our start adn end slices should be to get all the frames
		//for this Z plane
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

	//Select our image
	selectWindow(imageName);
	subSlices = nSlices;
    	
    //Create an array to store which of the current substack slices we're keeping - fill with zeros
	framesToKeepArray = newArray(subSlices);
    framesToKeepArray = Array.fill(framesToKeepArray, 0);

	setOption("AutoContrast", true);
	run("Tile");

    //Looping through the number of frames the user selected to keep, ask the user to
	//scroll to a frame to retain, if that frame is retained, store the slice index in
	//sliceSelectionArray
	sliceSelectionArray = newArray(noFramesToSelect);
	
	//Create an array where each value is a slice number in the stack
	slicesInStack = getArrayOneToMaxValue(subSlices);
    for(currFrame=0; currFrame < noFramesToSelect; currFrame++) {
            
		selectWindow(imageName);
		setBatchMode("show");
        waitForUser("Scroll onto the frame to retain and click 'OK'");
        keptSlice = getSliceNumber();
		print("Slice selected: ", keptSlice);
		run("Delete Slice");

		//Store the slice numbers of the stacks that we're selecting and then deleting
		sliceSelectionArray[currFrame] = keptSlice-1;

		//Find what actual slice number this corresponds to
		actualSliceChosen = slicesInStack[keptSlice-1];
		print('Corresponding slice chosen', actualSliceChosen);

		//Delete this slice from the slicesInStack array just like we did
		//the stack
		slicesInStack = Array.deleteValue(slicesInStack, actualSliceChosen);

		//Store the actual slice chosen as its index in framesToKeepArray
		framesToKeepArray[(actualSliceChosen-1)] = actualSliceChosen;
	}

	setOption("AutoContrast", false);

    return framesToKeepArray;
}

function populateAndSaveSlicesToUseFile(slicesToUseFile, arrayOfChosenSlices) {

	tableName = File.getNameWithoutExtension(slicesToUseFile);
	
	//Save our array in a csv file so we can read this in later
	//Save the array of slices we've chosen to keep
	Table.create(tableName);
	selectWindow(tableName);
	Table.setColumn("Slices", arrayOfChosenSlices);
	
	//If the output directory for the input image hasn't already been made, make it
	directoryToMake = newArray(File.getDirectory(slicesToUseFile));
	makeDirectories(directoryToMake);

	//Save our table
	Table.save(slicesToUseFile);

	//Close our table
	actualTableName = Table.title;		
	selectWindow(actualTableName);
	run("Close");

}

function manuallyApproveZPlanes(framesPerPlane, zPlane, framesToKeep) {

	//Create our substack of all frames at this z plane from the image renameAs
	subName = makeZPlaneSubstack(framesPerPlane, zPlane, "Timepoint");

	//Select the frames to retain from this substack and return this as an array
	manualFramesToKeep = selectFramesManually(framesToKeep, subName);

	//Close our Z plane substack
	selectWindow(subName);
	run("Close");

	//Return the frames we chose to keep
	return manualFramesToKeep;

}

function manuallyApproveTimepoints(toOpen, iniValues, framesToKeep) {

	//Rename a duplicate of our image as timepoint
	selectWindow(File.getName(toOpen));
	run("Duplicate...", "duplicate");
	rename("Timepoint");

	numberOfZPlanes = iniValues[3];
	framesPerPlane = iniValues[4];

	//Loop through all Z points in our image
	for(zPlane=1; zPlane<(numberOfZPlanes + 1); zPlane++) {

		//Manually approve the frames at this Z plane
		zFramesToKeep = manuallyApproveZPlanes(framesPerPlane, zPlane, framesToKeep);

		//Concatenate teh arrays of chosen frames for all these z planes
		if(zPlane == 1) {
			finalZFrameImages = zFramesToKeep;
		} else {
			finalZFrameImages = Array.concat(finalZFrameImages, zFramesToKeep);
		}

	}

	//Close our timepoint image
	selectWindow("Timepoint");
	run("Close");

	//Return our chosen Z frames
	return finalZFrameImages;

}

function manualFrameSelection(directories, manualFlaggedImages, iniValues, framesToKeep) {
	
	//Loop through the files in the manually flagged images array
	for(i=0; i<manualFlaggedImages.length; i++) {

		proceed = false;
		
		//If we're doing manual processing and we don't have a list of slices to use for an 
		//image, but the image exists, proceed
		slicesToUseFile = directories[1] + File.getNameWithoutExtension(manualFlaggedImages[i]) + "/Slices To Use.csv";
		toOpen = directories[0] + manualFlaggedImages[i];
		if(File.exists(slicesToUseFile)==0 && File.exists(toOpen)==1) {
			proceed = true;	
		}

        if(proceed == true) {

			print("Manually selecting frames for", File.getNameWithoutExtension(toOpen));
			
			open(toOpen);

			//Format the image for manual selection
			formatManualSelectionImage(toOpen);

			//Get our frames to keep from the image
			timepointFramestoKeep = manuallyApproveTimepoints(toOpen, iniValues, framesToKeep);

			populateAndSaveSlicesToUseFile(slicesToUseFile, timepointFramestoKeep);

            Housekeeping();

        } else {

			print("Either image ", File.getNameWithoutExtension(toOpen), " doesn't exist, or it has a SlicesToUse.csv file already");

		}	

    } 

}

function manualFrameSelectionWrapper(directories, manualFlaggedImages, iniValues, framesToKeep, manCorrect) {
	
	//If the user wants to manually select frames, and we have images eligibile for this (i.e. not being ignored from analysis or
	//already manually frames chosen
	if(manualFlaggedImages[0] != 'false' && manCorrect == 1) {

			print('Beginning manual frame selection');
			manualFrameSelection(directories, manualFlaggedImages, iniValues, framesToKeep);

	} else if(manualFlaggedImages[0] == 'false') {

		print('No images to manually choose frames for');
		
	} else if(manCorrect == 0) {

		print('User has not chosen to manually select frames');
		
	}

}

function imagesToAutomaticallyProcess(manualFlaggedImages, directories) {

		//For all the images in our input folder, check if they're in our manual flagged images array
		imagesInput = getFileList(directories[0]);
		for(currImage = 0; currImage < imagesInput.length; currImage++) {
			for(currManualCheck = 0; currManualCheck < manualFlaggedImages.length; currManualCheck++){

				//If they're in our manual flagged images array, exclude them
				slicesToUseFile = directories[1] + File.getNameWithoutExtension(manualFlaggedImages[currManualCheck]) + "/Slices To Use.csv";
				if(File.getName(imagesInput[currImage]) == manualFlaggedImages[currManualCheck] && File.exists(slicesToUseFile) != 1) {
					imagesInput[currImage] = 0;
					break;
				}
			}
		}

		imagesToProcessArray = Array.deleteValue(imagesInput, 0);

		//Return the array of images to put through processing
		return imagesToProcessArray;
}

function stackContrastAdjust(imageName) {

	//Adjust the contrast in the stack to normalise it across all Z depths and timepoints
	print("Adjusting Contrast Across Entire Stack");
	selectWindow(imageName);

	//Convert the image to 8-bit
	run("8-bit");
	setSlice(1);

	if(nSlices > 1) {
		run("Stack Contrast Adjustment", "is");
		stackWindow = getTitle();

		//Close the original image
		selectWindow(imageName);
		run("Close");

		//Rename the adjusted image to the original image name
		selectWindow(stackWindow);
		rename(imageName);
	}
	
	run("8-bit");

}

function expandCanvas(imageName) {

	//Increase the canvas size of the image by 500 pixels in x and y so that 
	//when we run registration on the image, if the image drifts we don't lose
	//any of it over the edges of the canvas
	selectWindow(imageName);
	print("Expanding Image Canvas");
	getDimensions(width, height, channels, slices, frames);
	run("Canvas Size...", "width="+(width+500)+" height="+(height+500)+" position=Center zero");

}

//This function removes any elements from an input array that conatins the string 'string' and returns it
function filterArray(fileLocations, string, keepFlag) {

	//For each element in the array
	for (i = 0; i < fileLocations.length; i++) {

		//Find whether the string exists in the current element
		stringInIndex = indexOf(fileLocations[i], string);

		//If we're using the function to keep elements that have this string
		if(keepFlag == true) {

			//Flag elements that don't have the string with 0's
			if(stringInIndex < 0) {
				fileLocations[i] = 0;
			}

		//If we're using the function to remove elements that have this string
		} else {

			//Set elements that have the string to 0
			if(stringInIndex > -1) {
				fileLocations[i] = 0;
			}
		}
	}

	//Return an array where these elements are removed
	toReturn = Array.deleteValue(fileLocations, 0);

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

	//Rename our original image, and our laplacian image
	selectWindow(zPlaneWindow);
	rename("toKeep");
	selectWindow(zPlaneWindow + " Laplacian");
	rename(zPlaneWindow);
	imageSlices = nSlices;

	//For each slice in the stack, store the maximum pixel value of the laplacian filtered slice
	maxArray = getSliceStatistics(zPlaneWindow, "max");

	//Close the laplacian filtered image
	selectWindow(zPlaneWindow);
	run("Close");

	//Rename our toKeep image back to its original name
	selectWindow("toKeep");
	rename(zPlaneWindow);

	//Return the max grey values of each slice of our laplacian filtered image
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

	//Here we register an image to itself first using the translation then using the affine method
	run("MultiStackReg", "stack_1=["+windowName+"] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
	run("MultiStackReg", "stack_1=["+windowName+"] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Affine]");


}

//Part of motion processing, takes an array (framesFlaggedForRetention) of images to turn into a reference frame,
//make take the images in the array from currentSubstackWindowName and turn them into a substack
//that we rename to renameTo, create an average projection of these frames 
function createReferenceFrame(framesFlaggedForRetention, currentSubstackWindowName, renameTo) {
	
	//Remove zeros from the array of images that we want to make a substack from
	framesToRetain=Array.deleteValue(framesFlaggedForRetention, 0);

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

//Adds our reference frame ontop of a stack, registers that stack to the reference frame using
//translation, then remove the reference frame
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

//Get statistics from the slices in our stack, either the mean or the max
//grey value
function getSliceStatistics(imageName, value) {

	if(value != "mean" && value != "max") {
		exit("getSliceStatistics() function input for value was not correctly formatted");
	}

	selectWindow(imageName);

	outputArray = newArray(nSlices);
	//Loop through getting the mean and max of each slice of imageName
	for(currSlice = 1; currSlice < (nSlices+1); currSlice++) {

		//Set the slice, get raw statistics
		setSlice(currSlice);
		getRawStatistics(nPixels, mean, min, max, std, hist);

		//Store our mean or max depending on what loop we're on
		if(value == "mean") {
			outputArray[currSlice-1] = mean;
		} else if (value == "max") {
			outputArray[currSlice-1] = max;
		}
	}

	//Return our values
	return outputArray;

}

function setToZeroIfCutoff(inputArray, framesPerPlane, rankCutoff, direction) {
	
	//Get the ranks of the values in our input array as rankedArray
	preRankedOutput=Array.rankPositions(inputArray);
	rankedArray=Array.rankPositions(preRankedOutput);

	//For each slice in the stack, get an array that has each slice as a value in it
	framesToKeep = getArrayOneToMaxValue(framesPerPlane);

	//For the number of frames we're retaining per Z plane
	for(currFrame = 0; currFrame < framesPerPlane; currFrame++) {	

		//If we're running the function to remove values below our cutoff, set these
		//slice indices to 0
		if(direction == 'below'){
			if (rankedArray[currFrame]<(rankedArray.length-rankCutoff)) {
				framesToKeep[currFrame] = 0;
			}

		//If we're running the function to remove values above our cutoff, set these
		//slice indices to 0
		} else if(direction == 'above') {
			if (rankedArray[currFrame] > rankCutoff-1) {
				framesToKeep[currFrame] = 0;
			}
		} else {
			exit("Direction argument in setToZeroIfCutoff() not specified correctly")
		}
	}

	//Return our array with slices that we're keeping, and 0's for the ones we're not
	return framesToKeep;


}

//Return an array of the mean grey value of the difference for each slice
//between the reference frame and subName
function diffDetector(referenceFrame, subName) {

	print("Detecting frames least different from reference");
	//Calculate the difference between the average projection and the stack
	imageCalculator("Difference create stack", subName, referenceFrame);
	
	//Measure the difference (mean grey value) for each slice - ideally all this code should be put into a function since it
	//is a repeat of the laplacian frame selection from earlier
	meanArray = getSliceStatistics("Result of " + subName, "mean");

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

	if(nSlices > 1) {

		run("Z-Spacing Correction", "input=[] type=[Image Stack] text_maximally="+layersToTest+" outer_iterations=100 outer_regularization=0.40 inner_iterations=10 inner_regularization=0.10 allow_reordering number=1 visitor=lazy similarity_method=[NCC (aligned)] scale=1.000 voxel=1.0000 voxel_0=1.0000 voxel_1=1.0000 render voxel=1.0000 voxel_0=1.0000 voxel_1=1.0000 upsample=1");

		closeImages(toClose);


		//Renames the output image to the toRename variable
		selectWindow("Z-Spacing: " + inputImage);
		rename(toRename);

		//Close the exception that is thrown by the rearranging of stacks
		selectWindow("Exception");
		run("Close");

	} else {

		rename(toRename);

	}

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

//Take an array of the selected images (imageArray) that we're going to use to create a cleaned version fo our collapsedName image
//Format a string that we can pass to the concenate function so that we can extract them
function makeImageFromChosenFrames(imageArray, collapsedName) {

	//Format our imageArray into an array of strings taht we can collapse and use to extract chosen frames
	arrayOfFormattedNames = newArray(imageArray.length);
	for(currElement = 1; currElement < imageArray.length + 1; currElement++){
		arrayOfFormattedNames[currElement-1] = "image" + currElement + "=" + imageArray[currElement-1];
	}

	//Collapse the frames then extract them from collapsedName
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

	//Take our timepoint stack, register it using translation, convert to 8 bit
	print("Registering timepoint stack");
	run("MultiStackReg", "stack_1="+timepointStack+" action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Translation]");
	selectWindow(timepointStack);
	run("8-bit");

	//Reorder the Z frames, register using affine
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

	//Create a substack of all the frames at this zPlane
	subName = makeZPlaneSubstack(framesPerPlane, zPlane, renameAs);

	//Create a reference frame from this stack using the manuallyChosenFrames
	referenceFrameDiff = "diffDetectZPlane" + zPlane;
	createReferenceFrame(manuallyChosenFrames, subName, referenceFrameDiff);
	
	selectWindow(subName);
	run("Close");

	//Return the name of our reference frame
	return referenceFrameDiff;

}

function autoCreateCleanedFrame(framesPerPlane, zPlane, renameAs, blurDetectorFrames, diffDetectorFrames) {

	//Create a substack of all the frames at this zPlane
	subName = makeZPlaneSubstack(framesPerPlane, zPlane, renameAs);

	//Get an array of the blur levels at each slice
	blurDetectorOutput = blurDetector(subName);
	
	//Get the indices of the frames to retain that are the least blurry
	framesToKeepBlur =  setToZeroIfCutoff(blurDetectorOutput, framesPerPlane, blurDetectorFrames, "below");

	//Create a reference frame from these frames
	referenceFrameBlur = "blurDetectZPlane" + zPlane;
	createReferenceFrame(framesToKeepBlur, subName, referenceFrameBlur);

	//Register our original Z substack to this reference frame
	registerToReferenceFrame(referenceFrameBlur, subName);

	//Of our newly registered substack, get an array indiciating the difference of these frames
	//to the reference frame
	diffDetectorOutput = diffDetector(referenceFrameBlur, subName);	

	//Get the indices of frames to retain that are teh least different
	framesToKeepDiff =  setToZeroIfCutoff(diffDetectorOutput, framesPerPlane, diffDetectorFrames, "above");
	
	//Create a reference frame from these least different frames
	referenceFrameDiff = "diffDetectZPlane" + zPlane;
	createReferenceFrame(framesToKeepDiff, subName, referenceFrameDiff);
	
	selectWindow(subName);
	run("Close");

	//Return the name of this final reference frame
	return referenceFrameDiff;
	
}


function createCleanedTimepoint(renameAs, imagePath, iniValues, blurDetectorFrames, diffDetectorFrames, manuallyChosenFrames) {

	//Get out the current timepoint from our input image
	selectWindow(File.getName(imagePath));
	run("Duplicate...", "duplicate");
	rename("Timepoint");

	numberOfZPlanes = iniValues[3];
	framesPerPlane = iniValues[4];

	//Create an array with one index for each Z plane
	finalZFrameImages = newArray(numberOfZPlanes);

	//Loop through all Z points in our image
	for(zPlane=1; zPlane<(numberOfZPlanes + 1); zPlane++) {

		//If we're not creating a cleaned timepoint from manually chosen frames
		if(manuallyChosenFrames[0] == 'false') {

			//Automatically get a cleaned frames for this Z point
			cleanedZFrame = autoCreateCleanedFrame(framesPerPlane, zPlane, renameAs, blurDetectorFrames, diffDetectorFrames);

		//Else we're doing this manually
		} else {

			//Get the manually chosen frames for this Z plane
			manualFramesThisZ = Array.slice(manuallyChosenFrames, (zPlane - 1) * framesPerPlane, framesPerPlane * zPlane);
			keptFramesRaw = Array.deleteValue(manualFramesThisZ, 0);
			keptFrames = keptFramesRaw.length;

			//If for some reason the chosen frames is more than what the user specified in the inputs, print this
			if(keptFrames != diffDetectorFrames) {
				print("Manually retained frames per Z: ", keptFrames);
				print("Number of frames chosen to average over: ", diffDetectorFrames);
				exit("Number of frames chosen manually doesn't equal number of frames chosen to average over in this run. See log for info");
			}

			//Manually extract a cleaned Z frame
			cleanedZFrame =  manualCreateCleanedFrame(framesPerPlane, zPlane, renameAs, manualFramesThisZ);
		}

		//Store the names of the images for each cleaned Z frame
		finalZFrameImages[zPlane-1] = cleanedZFrame;

	}

	//Make our cleaned timepoint stack from these frames
	timepointStack = "timepoint" + 1;
	makeImageFromChosenFrames(finalZFrameImages, timepointStack);

	//Format it
	formatTimepointStack(timepointStack, numberOfZPlanes, diffDetectorFrames);

	selectWindow(renameAs);
	run("Close");

	return timepointStack;

}

//Remove the extra space from the canvas that we added on earlier to facilitate registration without
//losing image information
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

	if(nSlices > 1) {

		run("Z Project...", "projection=[Max Intensity]");
		toClose = newArray(finalStack + "Mask", finalStack, "MAX_" + finalStack + "Mask");

	} else {

		toClose = newArray(finalStack + "Mask", finalStack);

	}
		
	
	run("Create Selection");
	run("To Bounding Box");
	
	roiManager("Add");
	selectWindow(finalStack);
	roiManager("Select", 0);
	run("Duplicate...", "duplicate");
	rename("dup");
	
	closeImages(toClose);

	//As this isn't a timelapse experiment, we can close our original input 
	//image and rename our registered timepoint as the input image
	selectWindow("dup");
	rename(renameAs);
	run("Select None");

}

//If the image isn't already calibrated, calibrate it using iniValues
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

function createCleanedStack(imagePath, iniValues, blurDetectorFrames, diffDetectorFrames, manuallyChosenFrames) {

		//Get the total number of frames in our image
		framesPerPlane = iniValues[4];
		numberOfZPlanes = iniValues[3];
		totalFrames = framesPerPlane * numberOfZPlanes;

		//If we have manually chosen frames, get these
		renameAs = "Timepoint";
		manualFramesThisTimepoint = newArray('false');
		if(manuallyChosenFrames[0] != 'false') {
			manualFramesThisTimepoint = manuallyChosenFrames;
		}

		//Create a cleaned timepoint from our image, either using manual or automatic methods
		timepointStack = createCleanedTimepoint(renameAs, imagePath, iniValues, blurDetectorFrames, diffDetectorFrames, manualFramesThisTimepoint);
		finalTimepointImages = newArray(1);
		finalTimepointImages[0] = timepointStack;

		//Create a final image using the chosen frames
		finalStack = "outputStack";
		makeImageFromChosenFrames(finalTimepointImages, finalStack);

		//Close the original input image and concatenate all the registered timepoint images
		selectWindow(File.getName(imagePath));
		run("Close");

		//Remove the extra space we padded our image with
		outputImageName = File.getName(imagePath);
		removeExtraSpace(finalStack, outputImageName);
		
		//Calibrate our final image
		calibrateImage(outputImageName, iniValues);

}

function saveAndMoveOutputImage(imagePath, directories) {

	//If we haven't made an output directory for our input image in the output 
	//folder, we make it
	noExtension = File.getNameWithoutExtension(imagePath);
	directoryToMake = newArray(directories[1]+noExtension+"/");
	makeDirectories(directoryToMake);

	//Save our image
	saveName =  noExtension + " processed.tif";
	selectWindow(File.getName(imagePath));
	saveLoc = directoryToMake[0] + saveName;
	saveAs("tiff", saveLoc);

	//Move our image from the input folder to the done folder
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

	//Close our saved image
	selectWindow(saveName);
	run("Close");

}


function createProcessedImageStacks(imagesToProcessArray, directories, iniValues, preProcStringToFind, blurDetectorFrames, diffDetectorFrames, autoProcessed, manualProcessed, imageName, autoPassedQA, manualPassedQA) {

	//If we have images to process
	if(imagesToProcessArray.length > 0) {
		if(imagesToProcessArray[0] != 0) {

			//For each image
			for(currImage = 0; currImage<imagesToProcessArray.length; currImage++) {

				//Find the index of our current image to process in our imageName array
				imageNameIndex = findMatchInArray(imagesToProcessArray[currImage], imageName);

				if(imageNameIndex == -1) {
					exit("Issue here at line 1258");
				}
				
				print("Creating cleaned stack for ", imagesToProcessArray[currImage]);
				imagePath = directories[0] + imagesToProcessArray[currImage];
				open(imagePath);
				
				//Adjust the contrast in the stack
				stackContrastAdjust(imagesToProcessArray[currImage]);
				
				//Expand its canvas
				expandCanvas(imagesToProcessArray[currImage]);
		
				//Get our manually chosen frames if they exist
				slicesToUseFile = directories[1] + File.getNameWithoutExtension(imagesToProcessArray[currImage]) + "/Slices To Use.csv";
				manuallyChosenFrames = newArray('false');
				if(File.exists(slicesToUseFile) == 1) {
					print("Using manually chosen frames to create processed stack for", imagesToProcessArray[currImage]);
					manuallyChosenFrames = getTableColumn(slicesToUseFile, "Slices");
				} else {
					print("Automatically choosing frames to create processed stack for", imagesToProcessArray[currImage]);
				}	
				
				//Create a cleaned stack using these frames, or manually chosen frames
				createCleanedStack(imagePath, iniValues, blurDetectorFrames, diffDetectorFrames, manuallyChosenFrames);
				
				//Save the output and move it to the done folder
				saveAndMoveOutputImage(imagePath, directories);
		
				print("Image processing for ", imagesToProcessArray[currImage], " complete");

				//Set our processing values to 1 
				if(File.exists(slicesToUseFile) == 1) {
					manualProcessed[imageNameIndex] = 1;
				} else {
					autoProcessed[imageNameIndex] = 1;
				}

				//Save these arrays into a table
				saveImagesToUseTable(imageName, autoProcessed, autoPassedQA, manualProcessed, manualPassedQA, directories);
				
			}
		
		} else {
			print("No images to process");
		}
	}
}

function findMatchInArray(valueToFind, checkInArray) {

	//Return the index where our valueToFind exists in our checkInArray
	for(checkAgainst = 0; checkAgainst < checkInArray.length; checkAgainst ++) {
		if(valueToFind == checkInArray[checkAgainst]) {
			return checkAgainst;
		}
	}

	//If it's not found, return -1
	return -1;

}

function saveImagesToUseTable(imageName, autoProcessed, autoPassedQA, manualProcessed, manualPassedQA, directories) {
	//Save these arrays into a table
	Table.create("Images to Use.csv");
	Table.setColumn("Image Name", imageName);
	Table.setColumn("Auto Processing", autoProcessed);
	Table.setColumn("Auto QA Passed", autoPassedQA);
	Table.setColumn("Manual Processing", manualProcessed);
	Table.setColumn("Manual QA Passed", manualPassedQA);
	Table.save(directories[1] + "Images to Use.csv");
	selectWindow("Images to Use.csv");
	run("Close");
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
fileLocations = filterArray(fileLocationsRaw, '.ini', false);

//For each image in our image storage location, copy it into our input directory if it isn't already
//in there (and isn't in the done folder either) and append the saved images with the preProcStringToFind
moveImageToInput(fileLocations, directories, preProcStringToFind);

//Now we get out the list of files in our input folder 
//once we've gone through all the microglia morphology images in our image storage directory
imagesInputRaw = getFileList(directories[0]);

//Only retain files in the input folder that contain the .tif string
imagesInput = filterArray(imagesInputRaw, '.tif', true);

//Point to the table where we store the status of our images in the processing pipeline
imagesToUseFile = directories[1] +  "Images to Use.csv";

//If the file exists, it means we've run at least this step before, so retrieve the stage all images are at
if(File.exists(imagesToUseFile) == 1) {

	//Retrieve our existing columns
	imageName = getTableColumn(imagesToUseFile, "Image Name");
	autoProcessed = getTableColumn(imagesToUseFile, "Auto Processing");
	autoPassedQA = getTableColumn(imagesToUseFile, "Auto QA Passed");
	manualProcessed = getTableColumn(imagesToUseFile, "Manual Processing");
	manualPassedQA = getTableColumn(imagesToUseFile, "Manual QA Passed");

	//If there is an image in our input folder that isn't in our table,
	//append a new default value to all the processing steps for that image
	for(index = 0; index < imagesInput.length; index++) {
		foundIndex = findMatchInArray(imagesInput[index], imageName);
		if(foundIndex == -1) {
			imageName = Array.concat(imageName, newArray(imagesInput[index]));
			autoProcessed = Array.concat(autoProcessed, Array.fill(newArray(1), 0));
			autoPassedQA = Array.concat(autoPassedQA, Array.fill(newArray(1), -1));
			manualProcessed = Array.concat(manualProcessed, Array.fill(newArray(1), 0));
			manualPassedQA = Array.concat(manualPassedQA, Array.fill(newArray(1), -1));

		}
	}

	//Return an array of the images that are flagged for manual processing
	manualFlaggedImages = getManualFlaggedImages(imageName, autoProcessed, autoPassedQA, manualProcessed, manualPassedQA);

//If we don't have the file, we haven't run this yet
} else {

	//Set our arrays to their default values
	imageName = imagesInput;
	autoProcessed = newArray(imageName.length);
	Array.fill(autoProcessed, 0);
	autoPassedQA = newArray(imageName.length);
	Array.fill(autoPassedQA, -1);
	manualProcessed = newArray(imageName.length);
	Array.fill(manualProcessed, 0);	
	manualPassedQA = newArray(imageName.length);
	Array.fill(manualPassedQA, -1);	

	print("No image IDs to be manually processed");
	manualFlaggedImages = newArray('false');

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
manualFrameSelectionWrapper(directories, manualFlaggedImages, iniValues, diffDetectorFrames, manCorrect);

//Get the list of images we're going to process - if we've selected to process manual images, these
//are what we process, else we do non-manually flagged images
imagesToProcessArray = imagesToAutomaticallyProcess(manualFlaggedImages, directories);

imagesToProcessArrayClean = filterArray(imagesToProcessArray, '.tif', true);

createProcessedImageStacks(imagesToProcessArrayClean, directories, iniValues, preProcStringToFind, blurDetectorFrames, diffDetectorFrames, autoProcessed, manualProcessed, imageName, autoPassedQA, manualPassedQA);

print("Image processing complete");
