function getNumberOfImagesToDisplay() {

	//Ask the user how many images to display on the screen at once for quality control and return this number
	stringa="How many images do you want to display on the screen at once?";
	Dialog.create("Experiment Information");
		
	Dialog.addNumber(stringa,1);
	Dialog.show();
	onScreen = Dialog.getNumber();

	if(onScreen == 0) {
		exit("Images to display can't be zero");
	}

	return(onScreen);

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
	output = Array.deleteValue(fileLocations, 0);

	//Then return the output array
	return output;
	
}

function findMatchInArray(valueToFind, checkInArray) {

	//Check in the other arrays
	for(checkAgainst = 0; checkAgainst < checkInArray.length; checkAgainst ++) {
		if(valueToFind == checkInArray[checkAgainst]) {
			return checkAgainst;
		}
	}

	return -1;

}

function qaEligible(autoProcessed, autoPassedQA, manualProcessed, manualPassedQA) {

	//If the image hasn't been auto processed (which is impossible if it is in the processedStacks away but for clarity)
	//We don't QA it
	if(autoProcessed != 1) {
		checkIt = false;
	}


	//If the image has been auto processed
	if(autoProcessed == 1) {

		//If it hasn't been QA'd for the auto processing, QA it
		if(autoPassedQA == -1) {
			checkIt = true;
		}

		//If it has already passed auto processing QA, ignore it
		if(autoPassedQA == 1) {
			checkIt = false;
		}


		//If it failed auto processing QA
		if(autoPassedQA == 0) {

			//Check if it has been manually processed, and if not, don't QA it
			if(manualProcessed == 0) {
				checkIt = false;
			}

			//If it has been manually processed
			if(manualProcessed == 1) {

				//If it hasn't been QA'd after manual processing, QA it
				if(manualPassedQA == -1) {
					checkIt = true;
				//If it failed or passed manual QA, that it's last shot so we don't QA it	
				} else {
					checkIt = false;
				}
			}
		}
	}

	return checkIt;

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

//Get the number of images to display onscreen
onScreen = getNumberOfImagesToDisplay();

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)

//Populate our image info arrays
tableLoc = directories[1] + "Images to Use.csv";

if(File.exists(tableLoc) != 1) {
	exit("Need to run the stack preprocessing step first");
}

//If we already have a table get out our existing status indicators
imageName = getTableColumn(tableLoc, "Image Name");
autoProcessed = getTableColumn(tableLoc, "Auto Processing");
autoPassedQA = getTableColumn(tableLoc, "Auto QA Passed");
manualProcessed = getTableColumn(tableLoc, "Manual Processing");
manualPassedQA = getTableColumn(tableLoc, "Manual QA Passed");

//Here we set the macro into batch mode and run the housekeeping function which 
//clears the roimanager, closes all open windows, and clears the results table
setBatchMode(true);
Housekeeping();

//Count how many images we've opened (so we know when we hit enough to display to the user)
opened = 0;
for(currImage = 0; currImage < imageName.length; currImage++) {

	print('Image', imageName[currImage]);
	checkIt = qaEligible(autoProcessed[currImage], autoPassedQA[currImage], manualProcessed[currImage], manualPassedQA[currImage]);
	print('Eligible for QA:', checkIt);

	//If we're QAing the image
	if(checkIt == true) {

		openName = directories[1]+File.getNameWithoutExtension(imageName[currImage])+"/"+File.getNameWithoutExtension(imageName[currImage])+" processed.tif";
		print('Opening file at:', openName);

		//Open each image and add 1 to the count of opened images
		open(openName);
		opened++;

		displayImages = false;

		//If we've opened enough images to satisfy our onScreen image value, we print that we've hit the limit
		//and reset the number of images we've opened
		if(opened != 0 && opened == onScreen) {
			print("Hit the limit");
			displayImages = true;
			opened = 0;
		//Otherwise if we're on our final opened image and we don't have enough images open to reach the limit, we print as such
		} else if (currImage==(imageName.length-1)) {
			print("Reached end of the directory and not enough images to reach limit");
			displayImages = true;
		}

		//If we've hit our limit or we're done opening images
		if(displayImages == true) {

			setOption("AutoContrast", true);
			//We get a list of all their titles
			allImages = getList("image.titles");
			
			//We tile all the open images, display them to the user, and ask the user to close the ones that don't pass QA
			setBatchMode("Exit and Display");
			run("Tile");
			waitForUser("Close the images that aren't good enough in terms of registration for analysis then press ok");
			openImages = getList("image.titles");

			//For each image that we opened initially
			for(checkedImage=0; checkedImage<allImages.length; checkedImage++) {
				kept = 'false';

				rawName = substring(allImages[checkedImage], 0, indexOf(allImages[checkedImage], ' processed.tif')) + '.tif';

				//Find if it is still open - if so, we kept it and flag as such
				indexOfImage = findMatchInArray(allImages[checkedImage], openImages);
				if(indexOfImage != -1) {
					kept = 'true';
					print('Keeping ', rawName);
				} else {
					print('Not keeping ', rawName);
				}

				//Get current info for this image from our images to use data store
				indexOfImage = findMatchInArray(rawName, imageName);

				//If we've manual processed this image, and not QA'd this, and we're not keeping it
				if(manualProcessed[indexOfImage] == 1 && kept == 'false' && manualPassedQA[indexOfImage] == -1) {
					manualPassedQA[indexOfImage] = 0;
					print('Image failed manual QA; ignoring from now on');

				//Otherwise if we've manual processed this image, and not QA'd this, and we're keeping it
				} else if(manualProcessed[indexOfImage] == 1 && kept != 'false' && manualPassedQA[indexOfImage] == -1) {
						manualPassedQA[indexOfImage] = 1;
						print('Image passed manual QA');
				
				//Otherwise if we've auto processed this image, and not QA'd this, and we're not keeping it
				} else if(autoProcessed[indexOfImage] == 1 && kept == 'false' && autoPassedQA[indexOfImage] == -1) {
					autoPassedQA[indexOfImage] = 0;
					print('Image failed automated QA; flagging for manual processing');

					doneFileLoc = directories[2] + imageName[indexOfImage];

					//We move this image back to the input folder from the done folder so we can manually process it
					wasMoved = File.rename(doneFileLoc, directories[0] + imageName[indexOfImage]);
					if(wasMoved == 0) {
						exit("Issue with moving image to input folder");
						//Could be because its already in input?
					} else {
						print("Image moved from Done to Input");
					}
						
				//Otherwise if we've auto processed this image, and not QA'd this, and we're keeping it
				} else if(autoProcessed[indexOfImage] == 1 && kept != 'false' && autoPassedQA[indexOfImage] == -1) {
					autoPassedQA[indexOfImage] = 1;
					print('Image passed automated QA');

				}


				//Save these arrays into a table
				saveImagesToUseTable(imageName, autoProcessed, autoPassedQA, manualProcessed, manualPassedQA, directories);

			}

			//We close all the open images
			if(nImages>0) {
				run("Close All");
			}

			print('Evaluated this batch of images; proceeding to the next');
				
		}

	}

}

print('Image QA checks complete');