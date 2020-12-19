function getMaskGenerationInputs() {

	//These are the required inputs from the user
	strings = newArray("What mask size would you like to use as a lower limit?",
	"What mask size would you like to use as an upper limit?",
	"What range would you like to use for mask size error?",
	"What increment would you like to increase mask size by per loop?",
	"What area should the local region around each cell location be? (in um)");

	//TCS is target cell size, we iteratively threshold our cells to reach the 
	//TCS +/- the range/ The TCS lower is the minimum TCS we want to get results 
	//from, the TCS upper is the highest. Increment is how much we increase the 
	//TCS we're using each iteration to go from TCS lower to TCS upper. Trace is 
	//whether the user wants to manually trace processes to add to the analysis

	Dialog.create("Info for each section");
		
	//Here we loop through the strings and add a box for numeric input for each
	for(i=0; i<strings.length-1; i++) {
		Dialog.addNumber(strings[i], 0);
	}
	Dialog.addNumber(strings[strings.length-1], 120);
			
	Dialog.show();
						
	//Retrieve user inputs and store the selections in the selection array
	for(i=0; i<strings.length; i++) {
		selection[i] = Dialog.getNumber();
	}

	return selection;

}

function makeImageNamesArray(directories, imageNameRaw, currSubstack, currXCoord, currYCoord) {

	//We create an array to store different names we need for our mask generation where [0] is the name to save an image as, [1] is the
	//fileName, and [2] is the LRName. [0] and [1] are repeats as we edit them differently within functions
	imageNamesArray = newArray(directories[1] + imageNameRaw + "/Candidate Cell Masks/"+"Candidate mask for " + currSubstack + " x " + currXCoord +  " y " + currYCoord + " .tif", 
	"Candidate mask for " + currSubstack + " x " + currXCoord +  " y " + currYCoord + " .tif",
	"Local region for " + currSubstack + " x " + currXCoord +  " y " + currYCoord + " .tif");

	return imageNamesArray;


}

function openAndCalibrateAvgProjImage(avgProjImageLoc, iniValues) {
	//We open the image then calibrate it before converting it to 8-bit
	open(avgProjImageLoc);
	avgProjImage = File.getName(avgProjImageLoc);
	selectWindow(avgProjImage);
	run("Properties...", "channels=1 slices=1 frames=1 unit=um pixel_width="+iniValues[0]+" pixel_height="+iniValues[1]+" voxel_depth="+iniValues[2]+"");
}

function coordinateWithinBuffer(avgProjImageLoc, currXCoord, currYCoord, bufferInPixels) {
	selectWindow(File.getName(avgProjImageLoc));
	getDimensions(originalWidth, originalHeight, originalChannels, originalSlices, originalFrames);
	
	//Calculate if our y or x coordinates or outside the bufer in pixels
	yInsideBuffer = (currYCoord > bufferInPixels) || (currYCoord < (originalHeight - bufferInPixels));
	xInsideBuffer = (currXCoord > bufferInPixels) || (currXCoord < (originalWidth - bufferInPixels));

	return yInsideBuffer && xInsideBuffer;

}

function getLRCoords(cellLocCoords, LRLengthPixels) {


	//Here we store x and y values that we would use to draw a 120x120um square aruond our coordinate - we store the coordinates
	//that would be the top left corner of this square as that is what we need to input to draw it
	LRCoords = newArray(cellLocCoords[0]-(LRLengthPixels/2), cellLocCoords[1]-(LRLengthPixels/2));
	//[0] is xcordn, [1] is ycordn

	//Idea here is that if our x or y coordinates are less than half a LR length away from the edge, the LR length we create is half the 
	//usual length + however far our coordinate is from the edge
	//We also set our rectangle making coordinates to 0 if they would be less than 0 (i.e. our coordinates are less than half the LR distance
	//from the pictre edges

	//For each of our cell coordinates
	for(currCoord = 0; currCoord < cellLocCoords.length; currCoord++) {

		//If that coordinate is too close to the bottom left of the image for us to create a
		//local region with the existing LR coordinates
		if(cellLocCoords[currCoord] < LRLengthPixels/2) {

			//Set our LR coord to 0 (else it would be -ve)
			LRCoords[currCoord] = 0;

		}
	}

	return LRCoords;


}


function getLRLengths(cellLocCoords, dimensionsArray, LRLengthPixels) {

	//This array is created to store the length in x and y of the local region we're going to draw - in theory it should be 120um
	//for both directions but if our coordinate is close enough to the edge of our image that this isn't true, we adjust it
	LRLengthArray = newArray(LRLengthPixels, LRLengthPixels);
	//[0] is xLength, [1] is yLength

	//For each of our cell coordinates
	for(currCoord = 0; currCoord < cellLocCoords.length; currCoord++) {

		//If that coordinate is too close to the bottom left of the image for us to create a
		//local region with the existing LR coordinates
		if(cellLocCoords[currCoord] < LRLengthPixels/2) {

			//Set the length to be shorter than the full length depending on
			//where our coordinate is
			LRLengthArray[currCoord]=(LRLengthPixels/2) + cellLocCoords[currCoord];

		//Otherwise if the coordinate is too close to the top right of the image
		} else if(cellLocCoords[currCoord] > (dimensionsArray[currCoord] - (LRLengthPixels/2))) {

			//Adjust the size of the local region we create accordingly
			LRLengthArray[currCoord]=(LRLengthPixels/2) + dimensionsArray[currCoord] - cellLocCoords[currCoord];

		}
	}

	return LRLengthArray;

}

function createLRImage(avgProjImageLoc, LRCoords, LRLengthArray) {

	imageTitle = File.getName(avgProjImageLoc);
	selectWindow(imageTitle);

	//Here we make our local region based on all the values we've calculated
	makeRectangle(LRCoords[0], LRCoords[1], LRLengthArray[0], LRLengthArray[1]);
	run("Duplicate...", " ");
	tifLess = File.getNameWithoutExtension(avgProjImageLoc);
	selectWindow(tifLess + "-1.tif");
	rename("LR");
	run("Select None");


}

function getOtsuValue(xCoord, yCoord) {

	//We then auto threshold the LR and then get the lower and upper threshold levels from the otsu method and call the lower threshold
	//otsu
	setAutoThreshold("Otsu dark");
	getThreshold(otsu, upper);
	print("Finding connected pixels from CP using threshold");

	//We get the grey value at that point selection, and then if the lower threshold of the image
	//is bigger than that value, we set it to that value
	pointValue = (getPixel(xCoord, yCoord)) - 1;
	if(otsu>=pointValue) {
		otsu = pointValue-1;
	}

	return otsu;

}

function getConnectedMask(xCoord, yCoord, thresholdVal) {

	//We then make the point on our image and find all connected pixels to that point that have grey values greater than the otsu value
	selectWindow("LR");
	makePoint(xCoord, yCoord);
	setBackgroundColor(0,0,0);
	run("Find Connected Regions", "allow_diagonal display_image_for_each start_from_point regions_for_values_over="+thresholdVal+" minimum_number_of_points=1 stop_after=1");
	imgNamemask=getTitle();
	rename("Connected");
	print("Connected pixels found");

}

function findMaximaInCoords() {

	selectWindow("Connected");
	run("Create Selection");
	getSelectionCoordinates(xpoints, ypoints)

	//We clear outside of our selection in our LR, then find the maxima in that and get the coordinates of the maxima
	//to store these coordinates as the optimal point selection location

	//We need to find the optimal location as we want our point selection to be on the brightest pixel on our target cell
	//to ensure that our point selection isn't on a local minima, which whould make finding connected pixels that are 
	//actually from our target cell very error-prone
	
	print("Fine-tuning CP point selection based on mask");
	selectWindow("LR");
	run("Duplicate...", " ");
	selectWindow("LR-1");
	makeSelection("freehand", xpoints, ypoints);
	run("Clear Outside");
	List.setMeasurements;

	//Here we get the max value in the image and get out the point selection associated with the maxima using the
	//"find maxima" function			
	topValue = List.getValue("Max");
	run("Select None");
	run("Find Maxima...", "noise=1000 output=[Point Selection]");
	getSelectionCoordinates(tempX, tempY);
	adjustedCellCoords = newArray(tempX, tempY);
	selectWindow("LR-1");
	run("Close");
	selectWindow("Connected");
	run("Close");

	return adjustedCellCoords;

}

selection = getMaskGenerationInputs();
//"What mask size would you like to use as a lower limit?",
//"What mask size would you like to use as an upper limit?",
//"What range would you like to use for mask size error?",
//"What increment would you like to increase mask size by per loop?",
//"What area should the local region around each cell location be? (in um)");

//Set the size of the square to be drawn around each cell in um
LRSize = selection[4];

//Here we calculate how many loops we need to run to cover all the TCS values 
//the user wants to use
numberOfLoops = ((selection[1]-selection[0])/selection[3])+1;

//Populate our image info arrays
imagesToUseFile = directories[1] + "Images to Use.csv";

if(File.exists(imagesToUseFile) != 1) {
	exit("Need to run the stack preprocessing and stack QA steps first");
}

//If we already have a table get out our existing status indicators
imageName = getTableColumn(imagesToUseFile, "Image Name");
autoPassedQA = getTableColumn(imagesToUseFile, "Auto QA Passed");
manualPassedQA = getTableColumn(imagesToUseFile, "Manual QA Passed");

//This is an array with the strings that come just before the information we want to retrieve from the ini file.
iniTextStringsPre = newArray("x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = ");

//Array to store the values we need to calibrate our image with
iniValues =  getIniData(directories[3], iniTextStringsPre);
//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ

////////////////////////////////////Automatic Microglial Segmentation///////////////////////////////////////////////////////////

//This is the main body of iterative thresholding, we open processed input images and use the coordinates of the cell locations previuosly 
//input to determine cell locations and create cell masks
for (currImage=0; currImage<imageName.length; currImage++) {	

		imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);

		statusTable = directories[1]+imageNameRaw+"/Cell Coordinate Masks/Cell Position Marking.csv";

		if(File.exists(statusTable) != 1) {
			exit("Run cell detection first");
		}

		substackNames = getTableColumn(statusTable, 'Substack');
		processed = getTableColumn(statusTable, 'Processed');
		qaValue = getTableCOlumn(statusTable, 'QC');

		for(currSubstack = 0; currSubstack < substackNames.length; currSubstack++) {
			if(processed[currSubstack == 1 && qaValue[currSubstack] == 1) {

				tcsStatusTable = directories[1]+imageNameRaw+"/TCS Status Substack(" + substackNames[currSubstack] +").csv";

				tcsValue = getOrCreateTableColumn(tcsStatusTable, "TCS", -1, numberOfLoops);
				tcsMasksGenerated = getOrCreateTableColumn(tcsStatusTable, "Masks Generated", -1, numberOfLoops);
				tcsQCChecked = getOrCreateTableColumn(tcsStatusTable, "QC Checked", -1, numberOfLoops);
				tcsAnalysed = getOrCreateTableColumn(tcsStatusTable, "Analysed", -1, numberOfLoops);

				if(tcsValue[0] == -1) {
					for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {
						tcsValue[TCSLoops] = selection[0]+(selection[3]*TCSLoops);
					}
				}

				for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {

					//limits is an array to store the lower and upper limits of the cell area we're using within this TCS loop, calculated
					//according to the error the user input
					limits = newArray(tcsValue[TCSLoops]-selection[2], tcsValue[TCSLoops]+selection[2]);
					//Selection: //[0] is TCSLower, [1] is TCSUpper, [2] is range, [3] is increment, [4] is framesToKeep, [5] is trace
					//Limits: [0] is lower limit, [1] is upper
	
					//This is the directory for the current TCS
					TCSDir=directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops]+"/";
					prevTCSDir = directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops-1]+"/";

					makeDirectories(TCSDir);

					if(tcsMasksGenerated[TCSLoops] == -1) {

						substackCoordinatesLoc = directories[1] + imageNameRaw + "/Cell Coordinates/" + "CP Coordinates for Substack(" substackNames[currSubstack] + ").csv";
						open(substackCoordinatesLoc);

						xCoords = getTableColumn(substackCoordinatesLoc, 'X');
						yCoords = getTableCOlumn(substackCoordinatesLoc, 'Y');

						cellMaskTable = TCSDir + "Mask Generation.csv";

						maskName = getOrCreateTableColumn(cellMaskTable, "Mask Name", -1, xCoords);
						maskTry = getOrCreateTableColumn(cellMaskTable, "Mask Try", -1, xCoords);
						maskSuccess = getOrCreateTableColumn(cellMaskTable, "Mask Success", -1, xCoords);
						xOpt = getOrCreateTableColumn(cellMaskTable, "xOpt", -1, xCoords);
						yOpt = getOrCreateTableColumn(cellMaskTable, "yOpt", -1, xCoords);

						prevTCSCellMaskTable = prevTCSDir + "Mask Generation.csv";
						prevMaskSuccess = getOrCreateTableColumn(prevTCSCellMaskTable, "Mask Success", 1, xCoords);

						//We now loop through all the cells for this given input image
						for(currCell=0; currCell<xCoords.length; currCell++) {

							imageNamesArray = makeImageNamesArray(directories, imageNameRaw, substackNames[currsubstack], xCoords[currCell], yCoords[currCell]);
							//[0] is saveName, [1] is fileName, [2] is LRName
						
							//If the current mask hasn't been tried, and making the mask previously was a success then we try to make a mask - the reason we check previously
							//is because our TCS sizes increase with each loop, so if we couldn't make a mask on a previous loop where the TCS was smaller, that means the mask 
							//must have been touching the edges of the image, so with a larger TCS, then we're guaranteed that the mask will touch the edges so we don't bother
							//trying to make a mask for it anymore
							if(maskTry[currCell]==-1 && prevMaskSuccess[currCell]==1) {
	
								//This is an array to store the size of the local region in pixels (i.e. 120um in pixels)
								LRLengthPixels=(LRSize*(1/iniValues[0]));
								//[3] is size of the local region, [0] is the pixel size

								//Here we work out the number of pixels that represent 5 microns so we can use this to calculate if the coordinates are within the 5um buffer zone
								//of the edge of the image
								fiveMicronsInPixels=5*(1/iniValues[0]);

								avgProjImageLoc = directories[1]+imageNameRaw+"/Cell Coordinate Masks/CP mask for Substack (" + currSubstack+").tif";
								openAndCalibrateAvgProjImage(avgProjImageLoc, iniValues);
								proceed = coordinateWithinBuffer(avgProjImageLoc, xCoords[currCell], yCoords[currCell], fiveMicronsInPixels);		
		
								//If the y coordinate isn't less than 5 microns from the bottom or top edges of the image, and the x coordinate isn't less than 5 pixels from the width, then we
								//proceed
								if(proceed == true){
		
									//This array stores the width and height of our image so we can check against these
									selectWindow(File.getName(avgProjImageLoc));
									getDimensions(originalWidth, originalHeight, originalChannels, originalSlices, originalFrames);
									dimensionsCheckingArray = newArray(originalWidth, originalHeight);

									LRCoords = getLRCoords(newArray(xCoords[currCell], yCoords[currCell]), LRLengthPixels);
									//Here we store x and y values that we would use to draw a 120x120um square aruond our coordinate - we store the coordinates
									//that would be the top left corner of this square as that is what we need to input to draw it

									LRLengthArray = getLRLengths(newArray(xCoords[currCell], yCoords[currCell]), dimensionsCheckingArray, LRLengthPixels);
									//This array is created to store the length in x and y of the local region we're going to draw - in theory it should be 120um
									//for both directions but if our coordinate is close enough to the edge of our image that this isn't true, we adjust it

									//Making and saving local regions, running first Otsu method and getting initial value on which to base iterative process	
									print("Coordinate number " + (currCell+1) + "/" + xCoords.length);
									print("Making local region image of 120um x 120um centered on X: " + xCoords[currCell] + " Y: " + yCoords[currCell]);

									createLRImage(avgProjImageLoc, LRCoords, LRLengthArray);

									otsu = getOtsuValue(xCoords[currCell], yCoords[currCell]);

									getConnectedMask(xCoords[currCell], yCoords[currCell], otsu);

									maximaCoordinates = findMaximaInCoords();

									xCoords[currCell] = maximaCoordinates[0];
									yCoords[currCell] = maximaCoordinates[1];

									//We're here in terms of standardising things
			
									//Now that we're certain we've got the optimal coordinates, we save our LR image
									selectWindow("LR");
									saveAs("tiff", storageFoldersArray[4]+imageNamesArray[2]);
									selectWindow(imageNamesArray[2]);
									rename("LR");
									run("Select None");
					
									//Here we are finding the same connected regions using the maxima as our point selection and then measuring the area
									//of the connected region to get an initial area size associated with the starting otsu value
									area = getConnectedArea(currentMaskValues[3], currentMaskValues[4], otsu);
									imgNamemask = getTitle();
									
									//Here we check the area output, and if it fits in certain conditions we either proceed with the iterative thresholding or move onto the next cell - more explanation can be found
									//with the corresponding functions for each condition
									
									//If it less than our lower limit, then we check if its touching edges and it not, we keep iterating
									if (area<limits[0]) {
										threshContinue=touchingCheck(imgNamemask, imgNamemask, imgNamemask, 0);
									
									//If its within our limits, we check if its touching edges, and if it isn't touching any edges we save it, else we keep going
									} else if (area<=limits[1] && area>=limits[0]) {
										print("Area is = "+currentLoopValues[0]+"um^2 +/- "+selection[2]+"um^2");
										threshContinue=touchingCheck(imgNamemask, imageNamesArray[0], imageNamesArray[1],1);
										
										//Set mask success to 1
										if(threshContinue == false) {
											currentMaskValues[2] = 1;
										}
		
									//If we're above the limits, we continue iterating
									} else if (area>limits[1]) {
										threshContinue=true;	
									}
			
									selectWindow(imgNamemask);
									run("Close");
									
									//These variables are changed depending on how many iterations a mask has stabilised for (regardless of whether it fits
									// the TCS +/- the range, as if it stabilized 3 times we keep it), and loopcount ticks up each iteration we go through
									//as we use this value to change the otsu we use for the subsequent iteration 
									maskGenerationVariables = newArray(0,0);
									//[0] is stabilized, [1] is loopcount

									imageT = getList("image.titles");
									otherT =  getList("window.titles");
									Array.show(imageT, otherT);
									found = false;
									for(currName = 0; currName < otherT.length; currName++) {
										if(otherT[currName] == "Mask Generation PreChange") {
											found = true;
											currName = 1e99;
										}
									}
									if(found==false) {
										setBatchMode("Exit and Display");
										waitForUser("Mask generation not present before entering while loop");
										setBatchMode(true);
									}
			
									//Here we are proceeding with the iterative thresholding
									while (threshContinue==true) {
						
										maskGenerationVariables[1]++; //Each iteration we increase loopCount, this modifies how we alter the threshold value
					
										//Here we have to constantly check if our Otsu value is above the top and adjust accordingly
										otsu = valueCheck(otsu, topValue);
			
										//This array stores out current otsu value normalised to 255 in index [0], and the next threshold value we'll use in postion [1] based
										//on a formula outlined later
										otsuVariables = newArray(otsu/255, (((otsu/255)*(((area-currentLoopValues[0])/maskGenerationVariables[1])/currentLoopValues[0]))+(otsu/255))*255);
										//[0] is otsuNorm, [1] is nextThresh
	
										//print("nextThresh: ", otsuVariables[1]);
										//print("otsuNorm: ", otsu/255);
										//print("area: ", area);
										//print("TCS: ", currentLoopValues[0]);
										//print("Loop count: ", maskGenerationVariables[1]);
										
										//nextTRaw=((otsuNorm*(((area-TCS[TCSLoops])/loopCount)/TCS[TCSLoops]))+otsuNorm); //Eq for calculating next threshold
		
										//Similarly here to check if our next threshold value is above the top and adjust accordingly
										otsuVariables[1] = valueCheck(otsuVariables[1], topValue);
					
										//Here we get another area from our find connected regions
										selectWindow("LR");
										//print("otsu to check: ", otsuVariables[1]);
										//print("bottom value: ", bottomValue);
										//print("top value: ", topValue);
										areaNew = getConnectedArea(currentMaskValues[3], currentMaskValues[4], otsuVariables[1]);
										imgNamemask = getTitle();
						
										//If we get the same area for 3 iterations we exit the iterative process, so here we count identical areas 
										//(but if for any one instance they are not identical, we rest the counter)
										if (areaNew==area){
											maskGenerationVariables[0]++;
										} else {
											maskGenerationVariables[0]=0;	
										}
			
										//Here, as before, we look at which condition the mask falls into and act appropriately to either continue iterating, 
										//save the mask, or discard the mask
		
										//If we're below the lower limit for area and not stabilised, we check for touching
										if(areaNew<limits[0] && maskGenerationVariables[0]!=3) {
											threshContinue=touchingCheck(imgNamemask, imgNamemask, imgNamemask, 0);
		
										//If we're within limits and not stabilised, we touchingCheck
										} else if (areaNew<=limits[1] && areaNew>=limits[0] && maskGenerationVariables[0]!=3) {	
											print("Area is = "+currentLoopValues[0]+"um^2 +/- "+selection[2]+"um^2");
											threshContinue=touchingCheck(imgNamemask, imageNamesArray[0], imageNamesArray[1],1);
										
										//If we're over the limits and not stabilised, we continue
										} else if (areaNew>limits[1] && maskGenerationVariables[0]!=3) {
											threshContinue=true;
										
										//If we're stabilised, we touching check with type 2
										} else if (maskGenerationVariables[0] == 3) {
											threshContinue = touchingCheck(imgNamemask, imageNamesArray[0], imageNamesArray[1],2);
										}
										
										selectWindow(imgNamemask);
										run("Close");
						
										//print("Old area:" + area);
										//print("Old otsu: "+ otsu);
										//print("Current area: "+ areaNew);
										//print("Current otsu:" + otsuVariables[1]);
										print("Stabilised:" + maskGenerationVariables[0]);
					
										//If we're continuing, then we reset our areas and otsus and go through this again
										if (threshContinue==true) {
											print("Continuing");
											otsu=otsuVariables[1];
											area=areaNew;
										
										//If we're done with this cell, we set maskSuccess to 1 if we've saved a mask
										} else {
											print("Finished");
											if(File.exists(imageNamesArray[0])==1) {
												currentMaskValues[2] = 1;
											}
										}
			
									} //Once the output of threshContinue==false, then we exit the process
									selectWindow("LR");
									run("Close");
								}
									
								//Now that we've attempted mask generation (successful or otherwise) we set this variable to 1	
								currentMaskValues[1]=1;	
			
								//Update and save our TCS analysis table

								imageT = getList("image.titles");
								otherT =  getList("window.titles");
								Array.show(imageT, otherT);
								found = false;
								for(currName = 0; currName < otherT.length; currName++) {
									if(otherT[currName] == "Mask Generation PreChange") {
										found = true;
										currName = 1e99;
									}
								}
								if(found==false) {
									setBatchMode("Exit and Display");
									waitForUser("Issue");
									setBatchMode(true);
								}
								
								selectWindow("Mask Generation PreChange");
								for(i1=0; i1<tableLabels.length; i1++) {
									if(i1==0 || i1 == 7) {
										stringValue = currentMaskValues[i1];
										Table.set(tableLabels[i1], i0, stringValue);
									} else {
										Table.set(tableLabels[i1], i0, currentMaskValues[i1]);
									}
								}
								
								//We then close it - as we create a new one for the next cell - otherwise we get issues with writing to things
								//whilst they're open
		
								if (isOpen("Results")) {
									run("Clear Results");
								}
								if(roiManager("count")>0) {
									roiManager("deselect");
									roiManager("delete");
								}
		
								selectWindow(imgName);
								close("\\Others");

								imageT = getList("image.titles");
								otherT =  getList("window.titles");
								Array.show(imageT, otherT);
								foundNow = false;
								for(currName = 0; currName < otherT.length; currName++) {
									if(otherT[currName] == "Mask Generation PreChange") {
										foundNow = true;
										currName = 1e99;
									}
								}
								if(foundNow==false && found == true) {
									setBatchMode("Exit and Display");
									waitForUser("Found eralier but not after closing");
									setBatchMode(true);
								}
											
							}
								
						}
				
						selectWindow("Mask Generation PreChange");
						Table.update;
						Table.save(TCSDir+"Mask Generation.csv");
						maskGTitle = Table.title;
						Table.rename(maskGTitle, "Mask Generation PreChange");	
						
						//Set masks generated to 1 for this TCS
						currentLoopValues[1]=1;
						
						//Update and save our TCS analysis table
						selectWindow("TCS Status");
						for(i0=0; i0<TCSColumns.length; i0++) {
							Table.set(TCSColumns[i0], TCSLoops, currentLoopValues[i0]);
						}
						Table.update;
						Table.save(directories[1]+imageNames[3]+"/TCS Status.csv");
						Housekeeping();

					}	
				}	
				
				if(isOpen("TCS Status")) {
					Table.rename("TCS Status", "ToBChanged");
				} else if (isOpen("TCS Status.csv")) {
					Table.rename("TCS Status.csv", "ToBChanged");
				}
				
			}

			if(isOpen("TobChanged")) {
				selectWindow("ToBChanged");
				run("Close");
			}
		}
}
