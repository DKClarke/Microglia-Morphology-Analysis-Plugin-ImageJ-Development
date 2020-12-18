

//These folder names are where we store various outputs from the processing 
//(that we don't need for preprocessing)
storageFolders=newArray("Cell Coordinates/", "Cell Coordinate Masks/",
	"Somas/", "Candidate Cell Masks/", "Local Regions/", "Results/");

//Set the size of the square to be drawn around each cell in um
LRSize = 120;

//These are the required inputs from the user

strings = newArray("What mask size would you like to use as a lower limit?",
"What mask size would you like to use as an upper limit?",
"What range would you like to use for mask size error?",
"What increment would you like to increase mask size by per loop?");

//TCS is target cell size, we iteratively threshold our cells to reach the 
//TCS +/- the range/ The TCS lower is the minimum TCS we want to get results 
//from, the TCS upper is the highest. Increment is how much we increase the 
//TCS we're using each iteration to go from TCS lower to TCS upper. Trace is 
//whether the user wants to manually trace processes to add to the analysis

Dialog.create("Info for each section");
	
//Here we loop through the strings and add a box for numeric input for each
for(i=0; i<strings.length; i++) {
	Dialog.addNumber(strings[i], 0);
}
		
Dialog.show();
					
//Retrieve user inputs and store the selections in the selection array
for(i=0; i<strings.length; i++) {
	selection[i] = Dialog.getNumber();
}

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

////////////////////////////////////Automatic Microglial Segmentation///////////////////////////////////////////////////////////

//This is the main body of iterative thresholding, we open processed input images and use the coordinates of the cell locations previuosly 
//input to determine cell locations and create cell masks
for (i=0; i<imageName.length; i++) {	

		imageNameRaw = File.getNameWithoutExtension(imageName[i]);

		statusTable = directories[1]+imageNameRaw+"/Cell Coordinate Masks/Cell Position Marking.csv";

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

				}

			//Here we begin looping through the different TCS values we're going to be analysing
			for(TCSLoops=0; TCSLoops<numberOfLoops; TCSLoops++) {
	
				//This is an array to store the associated values for the current TCS loop
				currentLoopValues = newArray(TCSColumns.length);
				//[0] is TCS, [1] is masks generated, [2] is QC checked, [3] is analysed, [4] is wrong obj

				//Set the TCS as the lowest TCS + the increment we want to increase by, X how many times we've increased
				//We set these variables so that TCS is the current TCS to use, and TCSLoops is the number of loops we've been through
				currentLoopValues[0]=selection[0]+(selection[3]*TCSLoops);

				//Here we fill our TCSValues array with all the associated data taken from previous instances
				//we've run this macro if we have generated a TCS Status.csv file before

				fillArray(TCSValues, TCSResultsRefs, TCSColumns, TCSResultsAreStrings, true); 
	
				//Here we fill our TCS Status table with data from our TCSValues array
				selectWindow("ToBChanged");
				for(i0=0; i0<numberOfLoops; i0++) {
					for(i1=0; i1<TCSColumns.length; i1++) {
						Table.set(TCSColumns[i1], i0, TCSValues[(numberOfLoops*i1)+i0]);
					}
				}
	
				selectWindow("ToBChanged");
				for(i0 = 0; i0<Table.size; i0++) {
					if(currentLoopValues[0] == Table.get("TCS", i0)) {
						//Here we fill our currentLoopValues table with the TCSValues data that corresponds to the TCS value
						//we're current processing - this will be a bunch of zeros if we haven't processed anything before
						for(i1=0; i1<TCSColumns.length; i1++) {
							currentLoopValues[i1] = Table.get(TCSColumns[i1], i0);
						}
					}
				}

				Table.rename("ToBChanged", "TCS Status");

				//limits is an array to store the lower and upper limits of the cell area we're using within this TCS loop, calculated
				//according to the error the user input
				limits = newArray(currentLoopValues[0]-selection[2], currentLoopValues[0]+selection[2]);
				//Selection: //[0] is TCSLower, [1] is TCSUpper, [2] is range, [3] is increment, [4] is framesToKeep, [5] is trace
				//Limits: [0] is lower limit, [1] is upper
	
				//This is the directory for the current TCS
				TCSDir=directories[1]+imageNames[3]+"/"+"TCS"+currentLoopValues[0]+"/";
	
				//Here we make a TCS specific directory for our input image if it doesn't already exist
				if(File.exists(TCSDir)==0) {
					File.makeDirectory(TCSDir);
				}
	
				//Here we store the full names of the directories in an array for access later
				storageFoldersArray=newArray(storageFolders.length);
	
				//Here we make sure we have all the working directories we need, either within or without the
				//TCS specific directory
				for(i0=0; i0<storageFolders.length; i0++) {

					//Depending on what storageFolder we're working with, the dirToMake and parentDir vary
					if(i0<3) {
						dirToMake=directories[1]+imageNames[3]+"/"+storageFolders[i0];
						parentDir=directories[1]+imageNames[3]+"/";	
					} else {
						dirToMake=TCSDir+storageFolders[i0];
						parentDir=TCSDir;	
					}

					//Either way, we store the parentDir and storageFolders[i0] value in storageFoldersArray
					storageFoldersArray[i0]=parentDir+storageFolders[i0];

					//And if dirToMake doesn't exist, we make it
					if(File.exists(dirToMake)==0) {
						File.makeDirectory(dirToMake);
					}	
				}
	
				//Here if we haven't already looped through this TCS, we enter the process
				if(currentLoopValues[1]==0) {
	
					//We use this variable to store the total number of cells we've counted for a given image
					totalCells=0;
	
					//These arrays are used to store all the X and Y coordinates, and the substack names associated with them
					tempX = newArray(1);
					tempY = newArray(1);
					tempName = newArray(1);

					//Here we get out the cell postion marking informatino about whther the positions were makred
					//correctly or if there were issues with the image
					open(directories[1]+imageNames[3]+"/Cell Coordinate Masks/Cell Position Marking.csv");
					selectWindow("Cell Position Marking.csv");
					QCArray = Table.getColumn("QC");
					ProcessedArray = Table.getColumn("Processed");
					detectionArray = Table.getColumn("Bad Detection");
					regArray = Table.getColumn("Bad Registration");
					Table.reset("Cell Position Marking.csv");
	
					coordPath = directories[1] + imageNames[3] + "/Cell Coordinates/";
	
					noStacks = getFileList(coordPath);
					//Here we loop through all 3 substacks of cell placements and add together all the cells in them
					for(i0=0; i0<noStacks.length; i0++) {
					
						//Find the number of coordinates for the associated chunk by opening the coordinates table and finding nResults
						imgName = substring(noStacks[i0], indexOf(noStacks[i0], "for ")+4, indexOf(noStacks[i0], ".csv"));
						inputpath=directories[1]+imageNames[3]+"/Cell Coordinates/"+noStacks[i0];
						print(ProcessedArray[i0], QCArray[i0], detectionArray[i0], regArray[i0]);

						//If the image has been processed, QC'd, and theres is no bad detection or bad registration, then proceed
						if(ProcessedArray[i0] == 1 && QCArray[i0] == 1 && detectionArray[i0] == 0 && regArray[i0] == 0) {
						
							//Add the nResults of the cell coordinates to the totalCells count
							//run("Clear Results");
							print(inputpath);
							open(inputpath);
							totalCells += Table.size;
	
							//Here we create an array to store the name of the image chunk 
							substackName = newArray(Table.size);
							for(i1=0; i1<Table.size; i1++) {
								substackName[i1] = imgName;
							}
	
							//Here we get out all the X and Y coordinates from the results table and store all the X's in tempX, and all the Y's
							//in tempY, as well as the substackNames in tempName
	
							selectWindow("CP coordinates for " + imgName + ".csv");
							currentX = Table.getColumn("X");
							currentY = Table.getColumn("Y");
							tempX = Array.concat(tempX,currentX);
							tempY = Array.concat(tempY, currentY);
							tempName = Array.concat(tempName, substackName);
							selectWindow("CP coordinates for " + imgName + ".csv");
							Table.reset("CP coordinates for " + imgName + ".csv");
						}

					}


					//If we have at least one coordinates to analyze
					if(totalCells!=0) {

						//Here we cut out all the zeros from the tempX, tempY,and tempName arrays and move the data into X,Y, and finalSub arrays
						X = newArray(1);
						Y = newArray(1);
						finalSub = newArray(1);
	
						X = removeZeros(tempX, X);
						Y = removeZeros(tempY, Y);
						finalSub = removeZeros(tempName, finalSub);
					
						//Here we make arrays to fill with the name of the current cell and whether we've attempted to create a mask from it already that we fill
						//with 1's by default
						maskSuccessPrev = newArray(totalCells);
						Array.fill(maskSuccessPrev, 1);
	
						//If we're not in the first TCS loop

						if(TCSLoops>0) {
		
							//We create an array to store these values from our previous TCS loop
							prevLoopValues = newArray(TCSColumns.length);
							//[0] is TCS, [1] is masks generated, [2] is QC checked, [3] is analysed, [4] is wrong obj, [5] is TCS error
				
	
							//Here we fill the array with the values from the previuos TCS loop as stored in TCSValues
	
							for(i0=0; i0<TCSColumns.length; i0++) {
								prevLoopValues[i0] = TCSValues[(numberOfLoops*i0)+(TCSLoops-1)];
							}
	
							//Here we open the Mask Generation.csv file from the previous TCS loop and get out the information
							//about which mask generation was successful and store these in the maskSuccessPrev array
							previousTCSDir=directories[1]+imageNames[3]+"/TCS"+prevLoopValues[0]+"/";
	

							run("Clear Results");
							open(previousTCSDir+"Mask Generation.csv");
							selectWindow("Mask Generation.csv");
							resultsNo=Table.size; 	
							for(i0=0; i0<resultsNo; i0++) {
								maskSuccessPrev[i0] = Table.get("Mask Success", i0);
							}
							Table.reset("Mask Generation.csv");
							//Array.show(maskSuccessPrev);
							//waitForUser("Check this line 2820");
							Table.update;
		
						}

						//This is an array of headers for data we want to record for the cells we're going to be creating masks for - xOpt and yOpt are the x and y coordinates
						//that are located on the pixel with the maximum grey value on that cell, details follow later
						//Mask name is the name of the mask, try is whether we tried generating a mask for it or not, success is whether it was a success
						valuesToRecord = newArray("Mask Name", "Mask Try", "Mask Success", "xOpt", "yOpt");
					
						//This is an array that will store all the data associated wtih the headers but in a single dimension, where the first maskDirFiles.length
						//indices correspond to "Mask Name", then "Mask Try" etc.
						analysisRecordInput = newArray(totalCells*valuesToRecord.length);
					
						//These are the locations of any previously generated tables that contain the valuesToRecord info
						resultsTableRefs = newArray(TCSDir+"Mask Generation.csv", TCSDir+"Mask Generation.csv", TCSDir+"Mask Generation.csv",
												TCSDir+"Mask Generation.csv", TCSDir+"Mask Generation.csv");
				
						//This is whether the results to get are strings or not
						resultsAreStrings = newArray(true, false, false, false, false);
			
						//Here we fill our analysisRecordInput with the data we want as outlined in valuesToRecord if it exists from previous runs of the macro
						fillArray(analysisRecordInput, resultsTableRefs, valuesToRecord, resultsAreStrings, true);
			
						//We then concatenate on the x and y coordinates of our cell positons as well the as the name of the substack these coordinates are in to our
						//analysisRecordInput array
						analysisRecordInput = Array.concat(analysisRecordInput, X);
						analysisRecordInput = Array.concat(analysisRecordInput, Y);
						analysisRecordInput = Array.concat(analysisRecordInput, finalSub);
						
						//We then also add on the headers for this data to our valuestoRecord array and make a new headers array that contains them both
						toAdd = newArray("X Coord", "Y Coord", "Substack Name");
						tableLabels = Array.concat(valuesToRecord, toAdd);
	
						//Here make a table that we fill with information that corresponds to table lables i.e.
						// "Mask Name", "Mask Try", "Mask Success", "xOpt", "yOpt", "X Coord", "Y Coord", "Substack Name"
			
						Table.create("Mask Generation PreChange");
						selectWindow("Mask Generation PreChange");
						for(i1=0; i1<totalCells; i1++) {
							for(i2=0; i2<tableLabels.length; i2++) {
								if(i2 == 0 || i2 == 7) {
									stringValue = analysisRecordInput[(totalCells*i2)+i1];
									Table.set(tableLabels[i2], i1, stringValue);
								} else {
									Table.set(tableLabels[i2], i1, analysisRecordInput[(totalCells*i2)+i1]);
								}
							}
						}

						if(isOpen("Mask Generation PreChange")==false) {
							setBatchMode("exit and display");
							waitForUser("Table not made or disappearead");
						}
	
						//We now loop through all the cells for this given input image
						for(i0=0; i0<totalCells; i0++) {
						
							//Here we create an array to store the following data for a given cell
							currentMaskValues = newArray(8);
							//[0] is mask name, [1] is mask try, [2] mask success, [3] xopt, [4] yopt, [5] x, [6] y, [7] substack
	
							//We fill our currentMaskValues with the correct data from analysisRecordInput by indexing into it in the appropriate locations
							for(i1=0; i1<currentMaskValues.length; i1++) {
								currentMaskValues[i1] = analysisRecordInput[(totalCells*i1)+i0];
							}
						
							//We create an array to store different names we need for our mask generation where [0] is the name to save an image as, [1] is the
							//fileName, and [2] is the LRName. [0] and [1] are repeats as we edit them differently within functions
							imageNamesArray = newArray(storageFoldersArray[3]+"Candidate mask for " + finalSub[i0] + " x " + X[i0] +  " y " + Y[i0] + " .tif", 
											"Candidate mask for " + finalSub[i0] + " x " + X[i0] +  " y " + Y[i0] + " .tif",
											"Local region for " + finalSub[i0] + " x " + X[i0] + " y " + Y[i0] + " .tif");
											//[0] is saveName, [1] is fileName, [2] is LRName
		
							//Here we set the cell name of the current mask to fileName
							currentMaskValues[0]=imageNamesArray[1];
						
							//If the current mask hasn't been tried, and making the mask previously was a success then we try to make a mask - the reason we check previously
							//is because our TCS sizes increase with each loop, so if we couldn't make a mask on a previous loop where the TCS was smaller, that means the mask 
							//must have been touching the edges of the image, so with a larger TCS, then we're guaranteed that the mask will touch the edges so we don't bother
							//trying to make a mask for it anymore
	
							if(currentMaskValues[1]==0 && maskSuccessPrev[i0]==1) {
	
								//If we haven't previously retrieved the calibration values for this image, then we fill the
								//iniTextValuesMicrons array with the calibration information and set gottenCalibration to true
								if(gottenCalibration == false) {

									getIniData(directoryName, iniTextValuesMicrons);
									gottenCalibration = true;
								}

								//Array.show(iniTextValuesMicrons);
								//waitForUser("Check if this is wrongly calibrated - last index should be 1 if wrong - also need to check how this relates to hippo vs V1");
			
								//This is an array to store the size of the local region in pixels (i.e. 120um in pixels)
								LRLengthPixels=(LRSize*(1/iniTextValuesMicrons[0]));
								//[3] is size of the local region, [0] is the pixel size
							
								//If the CP mask image isn't already open
								if(!isOpen("CP mask for " + finalSub[i0] + ".tif")) {
		
									//We open the image then calibrate it before converting it to 8-bit
									open(directories[1]+imageNames[3]+"/Cell Coordinate Masks/CP mask for " + finalSub[i0]+".tif");
									imgName = getTitle();
									run("Select None");
									run("Properties...", "channels=1 slices=1 frames=1 unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
									getDimensions(originalWidth, originalHeight, originalChannels, originalSlices, originalFrames);
									run("8-bit");	
								}
							
								//Here we create an array to store the coordinates we're going to be analysing for this cell
								coordsArray = newArray(X[i0], Y[i0]);
										
								//Here we work out the number of pixels that represent 5 microns so we can use this to calculate if the coordinates are within the 5um buffer zone
								//of the edge of the image
								fiveMicronsInPixels=5*(1/iniTextValuesMicrons[0]);
		
								//If the y coordinate isn't less than 5 microns from the bottom or top edges of the image, and the x coordinate isn't less than 5 pixels from the width, then we
								//proceed
								if (!(coordsArray[1]<=fiveMicronsInPixels) || !(coordsArray[1]>=(originalHeight-fiveMicronsInPixels)) || !(coordsArray[0]>=(originalWidth-fiveMicronsInPixels)) || !(coordsArray[0]<=fiveMicronsInPixels)) { 	
		
									//Here we store x and y values that we would use to draw a 120x120um square aruond our coordinate - we store the coordinates
									//that would be the top left corner of this square as that is what we need to input to draw it
									newCoordsArray = newArray(coordsArray[0]-(LRLengthPixels/2), coordsArray[1]-(LRLengthPixels/2));
									//[0] is xcordn, [1] is ycordn
		
									//This array is created to store the length in x and y of the local region we're going to draw - in theory it should be 120um
									//for both directions but if our coordinate is close enough to the edge of our image that this isn't true, we adjust it
									LRLengthArray = newArray(2);
									//[0] is xLength, [1] is yLength
		
									//This array stores the width and height of our image so we can check against these
									dimensionsCheckingArray = newArray(originalWidth, originalHeight);
			
									//Idea here is that if our x or y coordinates are less than half a LR length away from the edge, the LR length we create is half the 
									//usual length + however far our coordinate is from the edge
									//We also set our rectangle making coordinates to 0 if they would be less than 0 (i.e. our coordinates are less than half the LR distance
									//from the pictre edges
			
									//For each iteration we first do x then y coordinates
									for(i1=0; i1<2; i1++) {
										if(coordsArray[i1]<(LRLengthPixels/2)) {
											newCoordsArray[i1]=0;
											LRLengthArray[i1]=(LRLengthPixels/2) + coordsArray[i1];
										
										//Here we calculate what the length of our selection will have to be to take into account the coordinates location in the image
										} else if (coordsArray[i1]>(dimensionsCheckingArray[i1]-(LRLengthPixels/2))) {
											LRLengthArray[i1] = (LRLengthPixels/2)+(dimensionsCheckingArray[i1]-coordsArray[i1]);
										} else {
											LRLengthArray[i1] = LRLengthPixels;
										}
									}
			
									//Making and saving local regions, running first Otsu method and getting initial value on which to base iterative process	
									print("Coordinate number " + (i0+1) + "/" + totalCells);
									print("Making local region image of 120um x 120um centered on X: " + coordsArray[0] + " Y: " + coordsArray[1]);
									selectWindow(imgName);

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
										waitForUser("Not present at very start");
										setBatchMode(true);
									}
		
									//Here we make our local region based on all the values we've calculated
									makeRectangle(newCoordsArray[0], newCoordsArray[1], LRLengthArray[0], LRLengthArray[1]);
									run("Duplicate...", " ");
									tifLess = substring(imgName, 0, indexOf(imgName, ".tif"));
									selectWindow(tifLess + "-1.tif");
									rename("LR");
		
									//We then auto threshold the LR and then get the lower and upper threshold levels from the otsu method and call the lower threshold
									//otsu
									setAutoThreshold("Otsu dark");
									getThreshold(otsu, upper);
									print("Finding connected pixels from CP using threshold");
			
									getDimensions(LRwidth, LRheight, LRchannels, LRslices, LRframes); //These are the dimensions of our LR image
									run("Select None");
		
									//Here we create an array that stores the coordinates of a point selection right in the middle of our LR - this is assuming of course
									//that our selection was somewhere near the cell to begin with
									LRCoords = newArray(round((LRLengthPixels/2)+(LRwidth-LRLengthPixels)), round((LRLengthPixels/2)+(LRheight-LRLengthPixels)));
									//[0] is newXCoord, [1] is newYCoord
			
									//We get the grey value at that point selection, and then if the lower threshold of the image
									//is bigger than that value, we set it to that value
									pointValue = (getPixel(LRCoords[0], LRCoords[1])) - 1;
									if(otsu>=pointValue) {
										otsu = pointValue-1;
									}

									//print(pointValue);
									//print(otsu);
									//We then make the point on our image and find all connected pixels to that point that have grey values greater than the otsu value
									selectWindow("LR");
									makePoint(LRCoords[0], LRCoords[1]);
									setBackgroundColor(0,0,0);
									run("Find Connected Regions", "allow_diagonal display_image_for_each start_from_point regions_for_values_over="+otsu+" minimum_number_of_points=1 stop_after=1");
									imgNamemask=getTitle();
									rename("Connected");
									selectWindow("Connected");
									run("Invert");
									run("Create Selection");
									roiManager("add");
									print("Connected pixels found");
			
									//We clear outside of our selection in our LR, then find the maxima in that and get the coordinates of the maxima
									//to store these coordinates as the optimal point selection location
			
									//We need to find the optimal location as we want our point selection to be on the brightest pixel on our target cell
									//to ensure that our point selection isn't on a local minima, which whould make finding connected pixels that are 
									//actually from our target cell very error-prone
									
									print("Fine-tuning CP point selection based on mask");
									selectWindow("LR");
									run("Duplicate...", " ");
									selectWindow("LR-1");
									roiManager("Select", 0);
									run("Clear Outside");
									List.setMeasurements;
					
									//Here we get the max value in the image and get out the point selection associated with the maxima using the
									//"find maxima" function			
									topValue = List.getValue("Max");
									run("Select None");
									run("Find Maxima...", "noise=1000 output=[Point Selection]");
									getSelectionCoordinates(tempX, tempY);
									currentMaskValues[3] = tempX[0];
									currentMaskValues[4] = tempY[0];
									selectWindow("LR-1");
									run("Close");
									selectWindow("Connected");
									run("Close");
			
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
