function readAndGetColumnValue(resultsTableRefs, resultsAreStrings, resultsTableColumns) {

	//Check if our results table actually exists
	if(File.exists(resultsTableRefs)==1) {
		
		//Open our results table then loop through the results, filling our 
		//inputArray with the data depending on if its a string or not
		open(resultsTableRefs);
		tabName = Table.title;
		selectWindow(tabName);

		inputArray = newArray(Table.size);
		
		//Loop through the results table and fill the input array with the 
		//information we want to get
		for(i0=0; i0<Table.size; i0++) {
			if(resultsAreStrings==false) {
				inputArray[i0] = Table.get(resultsTableColumns, i0);
			} else {
				inputArray[i0] = Table.getString(resultsTableColumns, i0);
			}
		}
		selectWindow(tabName);
		Table.reset(tabName);
		run("Clear Results");	

		return inputArray;

	} else {

		print('Input table' + resultsTableRefs + ' doesn"t exist')
		return newArray('fail');

	}

}

function readAndGetMultipleColumns(resultsTableRefs, resultsAreStrings, resultsTableColumns) {

	count = 0;
	storageArray = newArray('fail');

	//Then loopping through the different data we want to fill our inputArray 
	//with
	for(i=0; i<resultsTableRefs.length; i++) {
		
		//We first clear results, then if our resultsTableRefs file exists, we 
		//open it 
		run("Clear Results");

	    inputArray = readAndGetColumnValue(resultsTableRefs[i], resultsAreStrings[i], resultsTableColumns[i]);

		if(inputArray[0] != 'fail') {

			if(count == 0) {
				storageArray = Array.copy(inputArray);
			} else {
				storageArray = Array.concat(storageArray, inputArray);
			}

			count = count + 1;

		}

	}

	return storageArray;

}

//This is a function used to fill an inputArray using data from a csv file 
//referenced in resultsTableRefs, from a column referenced in 
//resultsTableColumns, and whether that column contains strings are stored in 
//resultsAreStrings, and finally the argument inputsAreArrays can be set to true 
//if we're referencing multiple columns and multiple results tables to store in 
//a single inputArray

//InputArray needs to be a multiple of resultsTableRefs.length since if we have 
//multiple resultsTableRefs values, we need to store at least that many values 
//in the inputArray
function fillArray(resultsTableRefs, resultsTableColumns, 
	resultsAreStrings, inputsAreArrays) {
	
	//Clear the results table, check if our results table to load exists
	run("Clear Results");
	
	//Here if we are referencing multiple columns then inputsAreArrays will be 
	//true
	if(inputsAreArrays == true) {

		inputArray =  readAndGetMultipleColumns(resultsTableRefs, resultsAreStrings, resultsTableColumns);

	//If we're not getting multiple columns
	} else {

		inputArray = readAndGetColumnValue(resultsTableRefs, resultsAreStrings, resultsTableColumns);
		
	}

	return inputArray;

}

function findIniFile(iniFolder) {

	//We get the list of files in the iniFolder
	iniFileList = getFileList(iniFolder);
	
	//Find our ini file
	found = false;
	for(i=0; i<iniFileList.length; i++) {
		if(endsWith(toLowerCase(iniFileList[i]), "ini")) {
			//Create a variable that tells us which ini file to open
			iniToOpen = iniFolder + iniFileList[i]; 
			i = iniFileList.length;
			found = true;
		}
	}

	if(found == false) {
		print("No ini file found");
		return 'fail';
	} else {
		return iniToOpen;
	}

}

function parseIniValues(iniTextStringsPre, iniTextIndicesPreAdds, iniToOpen) {
		
	//We open the ini file as a string
	iniText = File.openAsString(iniToOpen);	
	
	iniTextValuesMicrons = newArray(iniTextStringsPre.length);

	//Looping through the values we want to grab
	for(i=0; i<iniTextStringsPre.length; i++) {

		//We create a start point that is the index of our iniTextStringsPre + iniTextIndicesPreAdds
		startPoint = indexOf(iniText, iniTextStringsPre[i])+iniTextIndicesPreAdds[i];

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
					print(realString);
					break;
				}
			}
		}

		//Parse our values
		iniTextValuesMicrons[i] = parseFloat(realString);
	}

	return iniTextValuesMicrons;

}

//This is a function to retrieve the data from the ini file. The ini file contains calibration information for the 
//entire experiment that we use to calibrate our images. iniFolder is the folder within which the ini file is located, 
//and iniTextValuesMicrons is an array we pass into the function that we fill with calibration values before returning it	
function getIniData(iniFolder, iniTextStringsPre) {

	iniToOpen = findIniFile(iniFolder);
	if(iniToOpen == 'fail') {
		return 'fail';
	}

	//This is an array of the length of characters in each iniTextStringsPre item, so we can look this far after the
	//start of each item to find the numeric value
	iniTextIndicesPreAdds = newArray(iniTextStringsPre.length);
	for(i = 0; i<iniTextStringsPre.length; i++) {
		iniTextIndicesPreAdds[i] = lengthOf(iniTextStringsPre[i]);
	}

	iniTextValuesMicrons = parseIniValues(iniTextStringsPre, iniTextIndicesPreAdds, iniToOpen);
		
	return iniTextValuesMicrons;
}

//Part of motion processing, takes an array (currentStackSlices), removes zeros from it, then
//creates a string of the numbers in the array before then making a substack of these slices
//from an imagesInput[i] window, registering them if necessary, before renaming them
//according to the info in motionArtifactRemoval
function getAndProcessSlices(currenStackSlices, motionArtifactRemoval, currTime) {
	
	//Here we order then cutoff the zeros so we get a small array of the 
	//slices to be retained
	imageNumberArrayCutoff=removeZeros(currenStackSlices);

	selectWindow("Timepoint");	
	timeSlices = nSlices;
					
	//This loop strings together the names stored in the arrayIn into a 
	//concatenated string (called strung) that can be input into the substack 
	//maker function so that we can make a substack of all kept TZ slices in
	//a single go - we input the imageNumberArrayCutoff array
	strung="";
	for(i1=0; i1<imageNumberArrayCutoff.length; i1++) {
		
		numb = imageNumberArrayCutoff[i1] - (currTime * timeSlices);
		string=toString(numb, 0);
						
		//If we're not at the end of the array, we separate our values with a 
		//comma
		if(i1<imageNumberArrayCutoff.length-1) {
			strung += string + ",";
	
		//Else if we are, we don't add anything to the end
		} else if (i1==imageNumberArrayCutoff.length-1) {
			strung += string;	
		}
	
	}
	
	//We then make a substack of our input image of the slices we're keeping 
	//for this particular ZT point
	selectWindow("Timepoint");	
	run("Make Substack...", "slices=["+strung+"]");
	rename("new");
	selectWindow("new");
	newSlices = nSlices;
		
	//If the image has more than 1 slice, register it and average project it 
	//so that we get a single image for this ZT point
	if(newSlices>1){
						
		print("Registering T", motionArtifactRemoval[2], " Z", motionArtifactRemoval[3]);
		if(false) {
		run("MultiStackReg", "stack_1=[new] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
		run("MultiStackReg", "stack_1=[new] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Affine]");
		}
		print("Registered");
						
		selectWindow("new");
		rename("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
		run("Z Project...", "projection=[Average Intensity]");
		selectWindow("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
		run("Close");
		selectWindow("AVG_T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
		rename("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);	
		
	//Otherwise just rename it appropriately
	} else {	
		selectWindow("new");
		rename("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);	
	}

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
				j = imageTitleList.length;
			}
		}
	}

	//Renames the output image to the toRename variable
	selectWindow("Z-Spacing: " + inputImage);
	rename(toRename);

	//Close the exception that is thrown by the rearranging of stacks
	selectWindow("Exception");
	run("Close");

}

////////////////////////////////////////////////////////////////////////////////
//////////////////////// Main user input sections //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function getWorkingAndStorageDirectories(){

    Dialog.create("Pick Directory");
    Dialog.addMessage("Choose morphology analysis working directory");
    Dialog.show();

    setOption("JFileChooser", true);
    MorphologyProcessing = getDirectory("Choose morphology analysis working directory");

    Dialog.create("Pick Directory");
    Dialog.addMessage("Choose the image storage directory");
    Dialog.show();
    //Get the parent 2P directory i.e. where all the raw 2P images are stored
    directoryName = getDirectory("Choose the image storage directory");
    setOption("JFileChooser", false);


    //Here we create an array to store the full name of the directories we'll be 
    //working with within our morphology processing directory
    directories=newArray(MorphologyProcessing+"Input" + File.separator, 
                        MorphologyProcessing+"Output" + File.separator, 
                        MorphologyProcessing+"Done" + File.separator,
						directoryName);
    //[0] is input, [1] is output, [2] is done, [3] is directoryName

    return directories;
}

function makeDirectories(directories) {

    //Here we make our working directories by looping through our folder names, 
    //concatenating them to our main parent directory
    //and making them if they don't already exist
    for(i=0; i<directories.length; i++) {
        if(File.exists(directories[i])==0) {
            File.makeDirectory(directories[i]);
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

    inputs_array = newArray(4)

    //Ask the user how many frames they want to retain for motion correction and how many frames they want to use
    //to make the average projection to compare other frames to (lapFrames) - also ask if the user would rather select
    //the frames to use manually 
    Dialog.create("Info for each section");
    Dialog.addNumber("How many frames per Z plane to average over for the final Z plane image?",1); 
    Dialog.addNumber("How many frames do you want to include in the average projection of least blurry frames?", 3);
    Dialog.addCheckbox("Manually select frames?", false);
    Dialog.addString("String to Search For", "Morphology");
    Dialog.show();

    inputs_array[0] = Dialog.getNumber();
    inputs_array[1] = Dialog.getNumber();
    inputs_array[2] = Dialog.getCheckbox();
    inputs_array[3] = Dialog.getString();

    return inputs_array;
    //[0] is fToKeep, [1] is lapFrames, [2] is manCorrect, [3] is preProcStringToFind

}

function getManualProcessingInputs(manCorrect) {
    
    manChoices = newArray(2)
    
    //If the user would rather select the frames to use manually, ask if they want to select the frames,
    //process the previously selected frames, or both - basically the second choice processes
    //frames selected when the first choice is chosen
    if(manCorrect == true) {
        Dialog.create("Manual Correction Options");
        Dialog.addCheckbox("Manually select frames?", true)
        Dialog.addCheckbox("Process images where frames have been previously selected?", true);
        Dialog.show();
        manChoices[0] = Dialog.getCheckbox();
        manChoices[1] = Dialog.getCheckbox();
    } else {
        manChoices[0] = false;
        manChoices[1] = false;
    }

    return manChoices;
    //[0] is frameSelect, [1] is frameProcess

}

//This function takes an input array, and removes all the 0's in it, outputting 
//it as the output array which must be passed in as an argument
function removeZeros(inputArray) {

	//Loop through the input array, if the value isn't a 0, we place that in our 
	//output array (which should be of length 1) before then concatenating an 
	//array of length 1 to it to add another location to store another non-zero 
	//value from the input array
	
    output = newArray(1);
	arrayToConcat = newArray(1);

	for(i=0; i<inputArray.length; i++) {
		if(inputArray[i]!=0) {
			currentIndex=output.length-1;
			output[currentIndex]=inputArray[i];
			output = Array.concat(output, arrayToConcat);
		}
	}

	//If the final value of the output array is 0, we trim the array by one
	if(output[output.length-1]==0) {
		output = Array.trim(output, output.length-1);
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

function moveImageToInput(fileLocations, directories){

    //Loop through all matching files
    for(i=0; i<fileLocations.length; i++) {

        //Here we take the location of the file that is a microglia morphology 
        //image, and we split up parts of the file name and store them in the 
        //parentArray for easier access where index [0] contains the whole string 
        //of image location, and each subsequent index is the parent directory of 
        //the previous index
        parentArray=newArray(3);
        parentArray[0] = fileLocations[i];
        for(i1=0; i1<(newArray.length); i1++){
            parentArray[i1+1] = File.getParent(parentArray[i1]);
        }
		//[0] is the full path, [1] is the treatment name, [2] is the animal name,
		//and [3] is the storage directory
    
        //Here we create a name to save the image as based the names in the last 2
        //directories of our image location and we add " Microglia Morphology" on 
        //to the end of it
        saveName = File.getName(parentArray[2]) + " " + 
                    File.getName(parentArray[1]) + " Microglia Morphology";

        //If this file is already saved in our input directory, or in our done 
        //directory, then we ignore it, but if it isn't we proceed
        if((File.exists(directories[0] + saveName + ".tif")==0 && File.exists(directories[2] + saveName + ".tif")==0)) {
                    
            //Here copy the image to the input folder with the saveName
            File.copy(fileLocations[i], directories[0] + saveName + ".tif");
        
        }
    }

}

function getManualFlaggedImages(tableLocation) {

	if(File.exists(tableLocation)==1) {

		open(tableLocation);
		tableName = Table.title;
		selectWindow(tableName);

		//If an image has a manual flag or is set to be ignored, 
		//flag it's image List values with a 0 
		manualFlag = Table.getColumn("Manual Flag");
		imageName = Table.getColumn("Image List");
		ignoreFlag = Table.getColumn("Ignore");
		for(currImage = 0; currImage<manualFlag.length; currImage++) {
			if(manualFlag[currImage]==0 || ignoreFlag[currImage] == 1) {
				imageName[currImage] = 0;
			}
		}
		forStorage = removeZeros(imageName);

		//Get the file name of the manually flagged images
		if(forStorage.length != 0) {
			ArrayConc = Array.copy(forStorage);
			for(currImage = 0; currImage<forStorage.length; currImage++) {
				ArrayConc[currImage] = File.getName(forStorage[currImage]);
			}
		} else {
			ArrayConc = newArray(1);
		}

		selectWindow(tableName);
		run("Close");

	} else {
		ArrayConc = newArray(1);
	}

	return ArrayConc;

}

//"OutputArray" is an array in which we store the output of this function
//InputName is a string file path of an image generated by this macro
//Function cuts up the file path of the inputName into different segments that
//contain different bits of info i.e. info about the animal and 
//timepoint that we store at index [0] in the array, the timepoint only at [1]
//the animal only at [2] and finally the file name without the .tif on the end that we store at [3]
function getAnimalTimepointInfo(inputName) {
  
  outputArray = newArray(4);
  
  outputArray[0] = File.getName(substring(inputName, 0, indexOf(inputName, " Microglia Morphology")));
  outputArray[1] = toLowerCase(substring(outputArray[0], lastIndexOf(outputArray[0], " ")+1));
  outputArray[2] = toLowerCase(substring(outputArray[0], 0, lastIndexOf(outputArray[0], " ")));
  outputArray[3] = File.getName(substring(inputName, 0, indexOf(inputName, ".tif")));

  return outputArray;

}

function openAndGetImageInfo(toOpen) {

    open(toOpen);
            
    //Get out the animal name info - animal and 
    //timepoint that we store at index [0] in the array, the timepoint only at [1]
    //the animal only at [2] and finally the file name without the .tif on the end
    //that we store at [3]
    imageNames = getAnimalTimepointInfo(toOpen);
    print("Preprocessing ", imageNames[0]); 
    print(File.getNameWithoutExtension(toOpen) + " opened");
        
    print("Preprocessing ", imageNames[0]); 

	//This is an array with the strings that come just before the information we want to retrieve from the ini file.
	iniTextStringsPre = newArray("x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = ");

	//Array to store the values we need to calibrate our image with
	iniTextValuesMicrons =  getIniData(iniFolder, iniTextStringsPre);
	//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ

    //Calculate the number of timepoints in the image, and also a value framesReorder that we pass in 
    //to reorganise our slices as we want
	selectWindow(File.getName(toOpen));
    timepoints = (iniTextValuesMicrons[3] * iniTextValuesMicrons[4])/nSlices;
    framesReorder = (iniTextValuesMicrons[3] * iniTextValuesMicrons[4])/timepoints;

	outputArray = newArray(timepoints, framesReorder);

    return outputArray;

}

function formatManualSelectionImage(toOpen, timepoints, framesReorder) {
   
   //Convert the image to 8-bit, then adjust the contrast across all slices 
    //to normalise brightness to that of the top slice in the image
    selectWindow(File.getName(toOpen));
    print("Converting to 8-bit");
    run("8-bit");

    //Here we reorder our input image so that the slices are in the right structure for motion artefact removal
    run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+timepoints+" frames="+framesReorder+" display=Color");
    run("Hyperstack to Stack");
    run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+framesReorder+" frames="+timepoints+" display=Color");

}

function getArrayOfImageSliceNumbers(toOpen) {

    //This makes an array with which is the length of the number of
	//Z we have per timepoint times the number of frames per Z (i.e., every slice in the stack)
	//We do this +1, then slice it, so that we get an array of the same length as our stack, starting
	//at a value of 1
	selectWindow(File.getName(toOpen));
	slices = nSlices;
    imageNumberArray = Array.getSequence(slices+1); 
    imageNumberArray = Array.slice(imageNumberArray, 1, imageNumberArray.length); 


    return imageNumberArray;

}

function makeTableFromArray(tableName, inputArray, columnNames) {

	//Create a results table to fill with previous data if it exists
	Table.create(tableName);
	
	//File the table with previous data
	for(i0=0; i0<(inputArray.length / columnNames.length); i0++) {
		for(i1=0; i1<columnNames.length; i1++) {
			Table.set(columnNames[i1], i0, inputArray[((inputArray.length / columnNames.length)*i1)+i0]);
		}
	}
	Table.update;

}

function makeCurrentSubstack(iniTextValuesMicrons, i0) {

    	//Here we create substacks from our input image - one substack 
        //corresponding to all the frames at one Z point
        subName="Substack ("+((iniTextValuesMicrons[4]*i0)+1)+"-"+ (iniTextValuesMicrons[4]*(i0+1))+")";
        selectWindow("Timepoint");
        slicesInTimepoint = nSlices;
        print(slicesInTimepoint);
        print(((iniTextValuesMicrons[4]*i0)+1)+"-"+ (iniTextValuesMicrons[4]*(i0+1)));
        run("Make Substack...", " slices="+((iniTextValuesMicrons[4]*i0)+1)+"-"+(iniTextValuesMicrons[4]*(i0+1))+"");
        rename(subName);

        return subName;

}

function selectFrames(fToKeep, subName) {
    
    selectWindow(subName);
    subSlices = nSlices;
	
    //Create an array to store which of the current substack slices we're keeping - fill with zeros
    slicesKeeping = newArray(subSlices);
    slicesKeeping = Array.fill(slicesKeeping, 0);

    setOption("AutoContrast", true);

    //Looping through the number of frames the user selected to keep, ask the user to
    //scroll to a frame to retain, the index of this frame in slicesKeeping is then set to 1
    for(currFrame=0; currFrame < fToKeep; currFrame++) {
            
        setBatchMode("Exit and Display");
        run("Tile");
        selectWindow(subName);
        waitForUser("Scroll onto the frame to retain on the image labelled 'Substack etc'");
        setBatchMode(true);
        keptSlice = getSliceNumber();
        print("Slice selected: ", keptSlice);
        print("If selecting more, select a different one");

        //keptSlice = 6;

        slicesKeeping[(keptSlice-1)] = 1;
            
    }

    setOption("AutoContrast", false);

    return slicesKeeping;
}

function setUnwantedToZero(i0, k, iniTextValuesMicrons, imageNumberArray, slicesKeeping) {

    //Close the image
    selectWindow(subName);
    subSlices = nSlices;
    run("Close");

    //If the user is keeping a particular frame, we retain that number in our imageNumberArray, else
    //we set it to zero
    for (i1=0;i1<subSlices;i1++) {
        if(slicesKeeping[i1] == 0) {
            imageNumberArray[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))] = 0;
        }
    }

    return imageNumberArray;

}

function manualSelectFramesPerTimepoint(toOpen, k, iniTextValuesMicrons, imageNumberArray) {
    
    selectWindow(File.getName(toOpen);
    //Get out the current timepoint, split it into a stack for each frame (i.e. 14 stacks of 26 slices)
    run("Duplicate...", "duplicate frames="+(k+1)+"");	
    rename("Timepoint");

    //Loop through all Z points in our image
    for(i0=0; i0<(iniTextValuesMicrons[3]); i0++) {

        subName = makeCurrentSubstack(iniTextValuesMicrons, i0);

        slicesKeeping = selectFrames(fToKeep, subName);
                
        imageNumberArray =  setUnwantedToZero(i0, k, iniTextValuesMicrons, imageNumberArray, slicesKeeping);

    }

    selectWindow("Timepoint");
    run("Close");

    return imageNumberArray;

}

function manualFrameSelection(directories, ArrayConc, directoryName, iniTextValuesMicrons) {

	//Loop through the files in the manually flagged images array
	for(i=0; i<ArrayConc.length; i++) {

        slicesToUseFile = directories[1] + ArrayConc[i] + "/Slices To Use.csv";
        toOpen = directories[0] + ArrayConc[i] + ".tif";
            
        //If we haven't already selected frames for the current image and it is in our input folder
        if(File.exists(slicesToUseFile)==0 && File.exists(toOpen)==1) {

            print("Manually selecting frames");
                    
			//Open the image, get ini values, use to calculate the numbber of timepoints and values
			//we need to format the stack for manual selection
            outputArray = openAndGetInfo(toOpen);
            //[0] is timepoints, [1] is framesReorder
            timepoints = outputArray[0];

			//Format the image for manual selection
			formatManualSelectionImage(toOpen, outputArray[0], outputArray[1]);

			//Get an array where each element represents a slice of the stack
			imageNumberArray = getArrayOfImageSliceNumbers(toOpen);

            //Reorder each individual timepoint stack in Z so that any out of position slices are positioned correctly for motion artifact detection and removal
            //Go through each timepoint
            for(k=0; k<timepoints; k++) {	

                imageNumberArray = manualSelectFramesPerTimepoint(toOpen, k, iniTextValuesMicrons, imageNumberArray);

            }

            tableName = File.getNameWithoutExtension(slicesToUseFile);

            //Save our array in a csv file so we can read this in later
            Table.create(tableName);
            selectWindow(tableName);
            Table.setColumn("Slices", imageNumberArray);

            //If the output directory for the input image hasn't already been made, make it
            if(File.exists(directories[1] + ArrayConc[i]+"/") == 0) {
                File.makeDirectory(directories[1]+ArrayConc[i] +"/");
            }

            Table.save(slicesToUseFile);
            actualTableName = Table.title;
            
            //Since we save it every time, we have to rename it to get rid of the .csv 
            if(actualTableName != tableName) {
                Table.rename(actualTableName,tableName);
            }
                
            selectWindow(tableName);
            run("Close");

            Housekeeping();

        }	

    } 

}

function manualFrameSelectionWrapper(manCorrect, frameSelect, directories, ArrayConc, directoryName, iniTextValuesMicrons) {
//If the user wants to manually process images and the user chose to select frames
	
	if(manCorrect == true && frameSelect == true) {
			
			manualFrameSelection(directories, ArrayConc, directoryName, iniTextValuesMicrons);

	}

}

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)
directoryName = directories[3];

//Loop through our working directories and make them if they don't already exist
makeDirectories(Array.slice(directories, 0, 3));

//Here we set the macro into batch mode and run the housekeeping function which 
//clears the roimanager, closes all open windows, and clears the results table
setBatchMode(true);
Housekeeping();

//Ask the user for inputs on frames to keep, frames to use for the laplacian blur detector, whether to
//manually correct frames, and the string to ID morphology images
inputs_array = getPreprocessingInputs();
fToKeep = inputs_array[0];
lapFrames = inputs_array[1];
manCorrect = inputs_array[2];
preProcStringToFind = inputs_array[3];

//If the user wants to manually process frames, get back whether they want to select frames to process,
//process already selected frames, or both
manChoices = getManualProcessingInputs(manCorrect);
frameSelect = manChoices[0];
frameProcess = manChoices[1];

//Here we run the listFilesAndFilesSubDirectories function on our parent 2P 
//raw data location looking for locations that are labelled with the user indicated string 
//i.e. we find our morphology images
fileLocations = listFilesAndFilesSubDirectories(directoryName, preProcStringToFind);

//For each image in our image storage location, copy it into our input directory if it isn't already
//in there (and isn't in the done folder either)
moveImageToInput(fileLocations, directories);

//Now we get out the list of files in our input folder 
//once we've gone through all the microglia morphology images in our image storage directory
imagesInput = getFileList(directories[0]);

Housekeeping();

//If we have an 'images to use' file in our output folder, get out the images to use from it and
//store in Array Conc
imagesToUseFile = directories[1] +  "Images to Use.csv"
ArrayConc = getManualFlaggedImages(imagesToUseFile);

manualFrameSelectionWrapper(manCorrect, frameSelect, directories, ArrayConc, directoryName, iniTextValuesMicrons);

//If we're going to frame process our manually selected frames, or we're not manually processing motion issues
if(manCorrect == false || manCorrect == true && frameProcess == true ) {

	//If we want to process our manually selected frames, set the image array to the manually flagged images
	if(manCorrect == true) {
		imagesInput = ArrayConc;
		
		for(currCheck = 0; currCheck < imagesInput.length; currCheck++) {
			imagesInput[currCheck] = toString(imagesInput[currCheck]) + ".tif";
		}

	//Otherwise get a list of the images in the input folder before removing from this list any images
	//that have been flagged for manual analysis i.e. images that haven't been registered before
	} else {
		imagesInput = getFileList(directories[0]);
		for(currInput = 0; currInput < imagesInput.length; currInput++) {
			noTif = substring(imagesInput[currInput], 0, indexOf(imagesInput[currInput], ".tif"));
			for(currConc = 0; currConc < ArrayConc.length; currConc++) {
				if(ArrayConc[currConc] == noTif) {
					imagesInput[currInput] = 0;
					currConc = 1e99;
				}
			}
		}	
		newImages = removeZeros(imagesInput);			
		imagesInput = newImages;			
	}
}

//Loop through the files in the input folder
for(i=0; i<imagesInput.length; i++) {
		
	//If the file exists in our input folder, we proceed
	proceed = false;
	if(File.exists(directories[0] + imagesInput[i])==1) {
		proceed = true;
	}

	//Though if we're doing manual correction and don't have a list of the frames to use, we don't proceed
	if(manCorrect == true && File.exists(directories[1] + substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv")==0) {
		proceed = false;
	}

	if(proceed == true) {

		toOpen = directories[0] + imagesInput[i];

		outputArray =  openAndGetInfo(toOpen, directoryName);
		timepoints = outputArray[0];

		windowName = File.getName(toOpen);
		
		if(false) {
			print("Stack Contrast Adjusting");
			selectWindow(imagesInput[i]);
			setSlice(1);
			run("Stack Contrast Adjustment", "is");
			stackWindow = getTitle();
			selectWindow(imagesInput[i]);
			run("Close");
			selectWindow(stackWindow);
			rename(imagesInput[i]);
			run("8-bit");
		}

		//Increase the canvas size of the image by 100 pixels in x and y so that 
		//when we run registration on the image, if the image drifts we don't lose
		//any of it over the edges of the canvas
		getDimensions(width, height, channels, slices, frames);
		run("Canvas Size...", "width="+(width+500)+" height="+(height+500)+" position=Center zero");

		//Start motion artifact removal here
		print("Starting motion artifact removal");

		//This array stores information we need to refer to during motion artifact 
		//removal - i.e. the current timepoint we're processing as well as the 
		//current z position we're processing, and the timepoint and z position 
		//labels we want to use (these are appended with 0's if necessary so that
		//all timepoints and z positions have the same number of digits)
		motionArtifactRemoval = newArray(0,0,0,0);
		//[0] is tNumber, [1] is zSlice, [2] is tOut, [3] is zLabel

		//This is an array we fill with the names of the processed timepoint stacks
		timepointNamesCutoff = newArray(timepoints);

		//If we're working with manually chosen frames, get them out as imageNumberArray, else
		//generate imageNumberArray as all the slices in the image, and copy this to a forLap object
		//which we use to select frames for our laplacian average - also, if we're not doing manual analysis but there exists a
		//manually chosen frame table for our image, use that instead
		if(manCorrect == true || manCorrect == false && File.exists(directories[1] +substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv")==1) {

			open(directories[1] + substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv");
			selectWindow("Slices To Use.csv");
			imageNumberArray = Table.getColumn("Slices");
			selectWindow("Slices To Use.csv");
			run("Close");
			
		} else {

			//This makes an array with a sequence 0,1,2...slices
			imageNumberArray = Array.getSequence(nSlices+1); 

			//This array is used in motion artifact removal to store the image numbers 
			//being processed that contains 1,2,3...slices
			imageNumberArray = Array.slice(imageNumberArray, 1, imageNumberArray.length); 
			forLap = Array.copy(imageNumberArray);
			
		}
			

		//Reorder each individual timepoint stack in Z so that any out of position slices are positioned correctly for motion artifact detection and removal
		//Go through each timepoint
		for(k=0; k<timepoints; k++) {

			//Set our current z slice to 0
			motionArtifactRemoval[1] = 0;
			selectWindow(imagesInput[i]);
			
			//Get out the current timepoint, split it into a stack for each frame (i.e. 14 stacks of 26 slices)
			run("Duplicate...", "duplicate frames="+(k+1)+"");
			selectWindow(substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "-1.tif");	
			rename("Timepoint");
				
			slicesForZ = nSlices;

			//This array is used to store the square difference between images and 
			//their references in artifact removal
			intDenDiff=newArray(slicesForZ); 
	
			//This array is used to store which images pass the motion artifact 
			//removal process using the cutoff method
			imagesToCombineCutoff=newArray(iniTextValuesMicrons[3]); 
		
			//Loop through all Z points in our image
			for(i0=0; i0<(iniTextValuesMicrons[3]); i0++) {
	
				//If our z or t labels are below 10, prefix with a 0
				for(i1=0; i1<2; i1++) {
					if(motionArtifactRemoval[i1]<10) {
						motionArtifactRemoval[i1+2] = "0" + motionArtifactRemoval[i1];
					} else {
						motionArtifactRemoval[i1+2] = "" + motionArtifactRemoval[i1];
					}
				}
				
				
				//If automatically selecting frames and we dont have a store of manually selected frames
				if(manCorrect == false && File.exists(directories[1] +substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv")==0) {

					//Here we create substacks from our input image - one substack 
					//corresponding to all the frames at one Z point
					subName="Substack ("+((iniTextValuesMicrons[4]*i0)+1)+"-"+(iniTextValuesMicrons[4]*(i0+1))+")";
					selectWindow("Timepoint");
					run("Make Substack...", " slices="+((iniTextValuesMicrons[4]*i0)+1)+"-"+(iniTextValuesMicrons[4]*(i0+1))+"");
					rename(subName);
				
					//As a way of detection blur in our imgaes, we use a laplacian of gaussian filter on our stack,
					//https://www.pyimagesearch.com/2015/09/07/blur-detection-with-opencv/
					//https://stackoverflow.com/questions/7765810/is-there-a-way-to-detect-if-an-image-is-blurry
							
					//We register our substack before running it through the laplacian filter
					print("Registering and removing artifacts from", subName);
					selectWindow(subName);
					subSlices=nSlices;
					run("FeatureJ Laplacian", "compute smoothing=1.0");
				
					//Close our pre laplacian image and rename our laplacian filtered image
					selectWindow(subName);
					rename("toKeep");
					selectWindow(subName + " Laplacian");
					rename(subName);
					imageSlices = nSlices;
						
					//For each slice in the stack, store the maximum pixel value of the laplacian filtered slice
					for(currSlice = 1; currSlice < (imageSlices+1); currSlice++) {
						setSlice(currSlice);
						getRawStatistics(nPixels, mean, min, max, std, hist);
						intDenDiff[((currSlice-1)+(i0*nSlices))] = max;
					}

					//Close the laplacian filtered image
					selectWindow(subName);
					run("Close");
					
					//Cutoff routine
						
					//This cutoff routine takes the measured square differences of each 
					//slice, and ranks them highest to lowest. We then select the best of 
					//the images (those with the lowest square differences). In this case we 
					//select the FramesToKeep lowest images i.e. if we want to keep 5 frames 
					//per TZ point, we keep the 5 lowest square difference frames per FZ.
						
					//Here we create an array that contains the intDenDiff values that 
					//correspond to the substack we're currently processing
					currentStackDiffs = Array.slice(intDenDiff, (i0*subSlices), (subSlices+(i0*subSlices)));
			
					//Here we rank the array twice, this is necessary to get the ranks of 
					//the slices so that the highest sq diff value has the highest rank and 
					//vice versa
					IMTArrayCutoffRank1=Array.rankPositions(currentStackDiffs);
					IMTArrayCutoffRank2=Array.rankPositions(IMTArrayCutoffRank1);
										
					//Here we compare the ranks to the frames to keep - if the rank is above 
					//our number of frames to keep, i.e. worse ranked than our threshold, we 
					//set the slice number to 0 in the array. This allows us to store only 
					//the slice numbers of the slices we want to use
					for (i1=0;i1<subSlices;i1++) {
						//print(IMTArrayCutoffRank2[i1]);
						//print(intDenDiff[i1]);
						if (IMTArrayCutoffRank2[i1]<(IMTArrayCutoffRank2.length-lapFrames)) {
							forLap[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))] = 0;
						}
						//print(forLap[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))]);
					}

					//Here we create a new array that stores the slice numbers for the 
					//substack we're currently working with
					currentStackSlices = Array.slice(forLap, ((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))), (subSlices+((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3]))))));
				
				} else {
					
					subSlices = iniTextValuesMicrons[4];
					
					//Here we create a new array that stores the slice numbers for the 
					//substack we're currently working with
					currentStackSlices = Array.slice(imageNumberArray, (i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3]))),  (subSlices+((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3]))))));

				}
						
				getAndProcessSlices(currentStackSlices, motionArtifactRemoval, k);

				//If automatically selecting frames and we dont have a store of manually selected frames
				if(manCorrect == false && File.exists(directories[1] + substring(imagesInput[i], 0, indexOf(imagesInput[i], ".tif")) + "/Slices To Use.csv")==0) {
	
					//Stick our average projected image in front of the ZT point to register then by translation (to minimize differences when comparing them)
					//before then removing the average projection from the stack
					run("Concatenate...", " title = wow image1=[T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]+"] image2=toKeep image3=[-- None --]");
					if(false) {
					run("MultiStackReg", "stack_1=[Untitled] action_1=Align file_1=[]  stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
					}
					selectWindow("Untitled");
					run("Make Substack...", "delete slices=1");
					selectWindow("Substack (1)");
					rename("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
					selectWindow("Untitled");
					rename("toKeep");

					//Calculate the difference between the average projection and the stack
					imageCalculator("Difference create stack", "toKeep", "T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
				
					//Measure the difference (mean grey value) for each slice - ideally all this code should be put into a function since it
					//is a repeat of the laplacian frame selection from earlier
					selectWindow("Result of toKeep");
					keepSlices = nSlices;
					diffArray = newArray(keepSlices);
					for(currSlice = 1; currSlice < (keepSlices+1); currSlice++) {
						setSlice(currSlice);
						getRawStatistics(nPixels, mean, min, max, std, hist);
						diffArray[currSlice-1]= mean;
					}
					selectWindow("Result of toKeep");
					run("Close");
					selectWindow("toKeep");
					run("Close");
					selectWindow("T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]);
					run("Close");

					//Here we rank the array twice, this is necessary to get the ranks of 
					//the slices so that the highest sq diff value has the highest rank and 
					//vice versa
					IMTArrayCutoffRank1=Array.rankPositions(diffArray);
					IMTArrayCutoffRank2=Array.rankPositions(IMTArrayCutoffRank1);
										
					//Here we compare the ranks to the frames to keep - if the rank is above 
					//our number of frames to keep, i.e. worse ranked than our threshold, we 
					//set the slice number to 0 in the array. This allows us to store only 
					//the slice numbers of the slices we want to use
					for (i1=0;i1<subSlices;i1++) {
						if (IMTArrayCutoffRank2[i1]>(fToKeep-1)) {
							imageNumberArray[i1+(i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))] = 0;
						}
					}
		
					//Here we create a new array that stores the slice numbers for the 
					//substack we're currently working with
					currentStackSlices = Array.slice(imageNumberArray, ((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3])))), (subSlices+((i0*subSlices) + (k*(subSlices*(iniTextValuesMicrons[3]))))));
	
					getAndProcessSlices(currentStackSlices, motionArtifactRemoval, k);

				}
		
				//At the slice index, add a string of the image number, and its t and z 
				//labels to the imagesToCombineCutoff array - this is in the format 
				//needed to be used with the image concatenator as we will be 
				//concatenating our Z slices together
				imagesToCombineCutoff[motionArtifactRemoval[1]]="image"+(motionArtifactRemoval[1]+1)+"=[T"+motionArtifactRemoval[2]+" Z"+motionArtifactRemoval[3]+"] ";
		
				//Increase the zSlice number
				motionArtifactRemoval[1]++;
	
				//If we've reached the end of our timepoint (as microglia morphology is 
				//only done on a single timepoint, this just means we've hit the end of 
				//the unique z positions in our stack), we concatenate them all together 
				//to get a single timepoint
				if(motionArtifactRemoval[1]==iniTextValuesMicrons[3]) {
							
					//This strung loop strings together the names stored in the 
					//arrayDuring into a format that can be used to concatenate only the 
					//selected open images
					strung="";
					for (i1=0; i1<imagesToCombineCutoff.length; i1++) {
						strung +=  imagesToCombineCutoff[i1];
					}	
		
					//Here we concatenate all the images we're keeping and rename it 
					//according to the timepoint label stored in motionArtifactRemoval
					run("Concatenate...", "title=[T"+motionArtifactRemoval[2]+"] "+strung+"");
		
					//Reorder the image in Z just to make sure everything lines up, before 
					//registering it

					selectWindow("T"+motionArtifactRemoval[2]);
					run("8-bit");
					print("Reordering and registering T", motionArtifactRemoval[2]);
					if(false) {
					run("MultiStackReg", "stack_1=[T"+motionArtifactRemoval[2]+"] action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Translation]");
					}
					selectWindow("T"+motionArtifactRemoval[2]);
					run("8-bit");
					zSpaceCorrection("T"+motionArtifactRemoval[2], (iniTextValuesMicrons[3]*5), "T"+motionArtifactRemoval[2]);
					selectWindow("T"+motionArtifactRemoval[2]);
					run("8-bit");
					if(false) {
					run("MultiStackReg", "stack_1=[T"+motionArtifactRemoval[2]+"] action_1=Align file_1=[] stack_2=None action_2=Ignore file_2[] transformation=[Affine]");
					}
					selectWindow("T"+motionArtifactRemoval[2]);
					run("8-bit");
					print("Done");
									
					//If we're only keeping a single frame (which means we won't have 
					//average projected our image earlier function) then we median blur 
					//our image 
					if(fToKeep==1) {
						selectWindow("T"+motionArtifactRemoval[2]);
						run("Median 3D...", "x=1 y=1 z=1");
					}
	
					timepointNamesCutoff[k] = "T"+motionArtifactRemoval[2];
			
				}

			}

			selectWindow("Timepoint");
			run("Close");
	
			motionArtifactRemoval[0]++;
			
		}
	
		//Close the original input image and concatenate all the registered timepoint images
		selectWindow(imagesInput[i]);
		run("Close");

		selectWindow(timepointNamesCutoff[(timepoints-1)]);
		run("Duplicate...", "duplicate");
		rename(timepointNamesCutoff[(timepoints-1)] + "Mask");
		setThreshold(1,255);
		run("Convert to Mask", "method=Default background=Dark");
			
		//Min project the mask showing all common pixels to get a single image that we turn into a selection, that we then impose on our concatenated stacks, turn into a proper square,
		//and then create a new image from the concatenate stacks that should contain no blank space
		selectWindow(timepointNamesCutoff[(timepoints-1)] + "Mask");
		run("Z Project...", "projection=[Max Intensity]");
		run("Create Selection");
		run("To Bounding Box");
		run("Duplicate...", "duplicate");
		rename("dup");

		selectWindow(timepointNamesCutoff[(timepoints-1)] + "Mask");
		run("Close");
		selectWindow(timepointNamesCutoff[(timepoints-1)]);
		run("Close");

		//As this isn't a timelapse experiment, we can close our original input 
		//image and rename our registered timepoint as the input image
		selectWindow("dup");
		rename(imagesInput[i]);
		run("Select None");
		
		//Here we check that the image is calibrated - if not we just recalibrate 
		//using the iniTextValuesMicrons data
		getPixelSize(unit, pixelWidth, pixelHeight);
		if(unit!="um") {
			selectWindow(imagesInput[i]);
			getDimensions(width, height, channels, slices, frames);
			run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
		}

		//If we haven't made an output directory for our input image in the output 
		//folder, we make it
		if(File.exists(directories[1]+imageNames[3]+"/")==0) {
			File.makeDirectory(directories[1]+imageNames[3]+"/");
		}

		selectWindow(imagesInput[i]);
		saveAs("tiff", directories[1]+imageNames[3]+"/" + imageNames[3]+ " processed.tif");

		wasMoved = File.rename(directories[0]+imagesInput[i], directories[2]+imagesInput[i]);
		if(wasMoved == 0) {
			print("Issue with moving image");
			waitForUser("Issue with moving image");
		}
		
	}

Housekeeping();