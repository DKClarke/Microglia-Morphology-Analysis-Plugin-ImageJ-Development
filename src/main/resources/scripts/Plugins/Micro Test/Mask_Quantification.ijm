setBatchMode(true);

//Get user input into where our working directory, and image storage directories, reside
directories = getWorkingAndStorageDirectories();
//[0] is input, [1] is output, [2] is done (working directories) [3] is directoryName (storage directory)

//Set the path to where we copy our analysed cells to so we can run a fractal analysis on this folder in 
//batch at a later timepoint - if this directory doesn't exist, make it
fracLacPath = directories[1]+"fracLac/";

//Populate our image info arrays
imagesToUseFile = directories[1] + "Images to Use.csv";

if(File.exists(imagesToUseFile) != 1) {
	exit("Need to run the stack preprocessing and stack QA steps first");
}

//If we already have a table get out our existing status indicators
imageName = getTableColumn(imagesToUseFile, "Image Name");

//This is an array with the strings that come just before the information we want to retrieve from the ini file.
iniTextStringsPre = newArray("x.pixel.sz = ", "y.pixel.sz = ", "z.spacing = ", "no.of.planes = ", "frames.per.plane = ");

//Array to store the values we need to calibrate our image with
iniValues =  getIniData(directories[3], iniTextStringsPre);
//Index 0 is xPxlSz, then yPxlSz, zPxlSz, ZperT, FperZ

////////////////////////////////////Automatic Microglial Segmentation///////////////////////////////////////////////////////////

//This is the main body of iterative thresholding, we open processed input images and use the coordinates of the cell locations previuosly 
//input to determine cell locations and create cell masks
for (currImage=0; currImage<imageName.length; currImage++) {
	
	print("Quantifying masks generated for image ",File.getNameWithoutExtension(imageName[currImage]));

	imageNameRaw = File.getNameWithoutExtension(imageName[currImage]);

	statusTable = directories[1]+imageNameRaw+"/Cell Coordinate Masks/Cell Position Marking.csv";

	if(File.exists(statusTable) != 1) {
		exit("Run cell detection first");
	}

	substackNames = substacksToUse(statusTable, 'Substack', 'Processed', 'QC');

	for(currSubstack = 0; currSubstack < substackNames.length; currSubstack++) {

		print("Processing substack ", substackNames[currSubstack]);

        tcsStatusTable = directories[1]+imageNameRaw+"/TCS Status Substack(" + substackNames[currSubstack] +").csv";
        
        if(File.exists(tcsStatusTable) != 1) {
            exit("Run mask generation first");
        }

		tcsValue = getTableColumn(tcsStatusTable, "TCS");
		tcsMasksGenerated = getTableColumn(tcsStatusTable, "Masks Generated");
		tcsQCChecked = getTableColumn(tcsStatusTable, "QC Checked");
		tcsAnalysed = getTableColumn(tcsStatusTable, "Analysed");

		for(TCSLoops=0; TCSLoops<tcsValue.length; TCSLoops++) {

			if(tcsAnalysed[TCSLoops] == -1) {

				print("Quantifying masks for TCS value of ", tcsValue[TCSLoops]);

				//This is the directory for the current TCS
				TCSDir=directories[1]+imageNameRaw+"/"+"TCS"+tcsValue[TCSLoops]+"/";
				TCSMasks = TCSDir + "Cell Masks/";

                cellMaskTable = TCSDir + "Substack (" + substackNames[currSubstack] + ") Mask Generation.csv";
                
                if(File.exists(cellMaskTable) != 1) {
                    exit("Run mask generation first");
                }

				print("Retrieving mask generation status");

				maskName = getTableColumn(cellMaskTable, "Mask Name");
				maskTry = getTableColumn(cellMaskTable, "Mask Try");
				maskSuccess = getTableColumn(cellMaskTable, "Mask Success");
				maskQA = getTableColumn(cellMaskTable, "Mask QA");
				maskQuant = getTableColumn(cellMaskTable, "Mask Quantified");

				//We now loop through all the cells for this given input image
				for(currCell=0; currCell<maskName.length; currCell++) {

					substackCoordName = substring(maskName[currCell], indexOf(maskName[currCell], 'for'));
					cellLRLoc = directories[1]+imageNameRaw+"/Local Regions/" + "Local region " + substackCoordName;

					if(maskSuccess[currCell] == 1 && maskQA[currCell] == 1 && maskQuant[currCell] == -1) {
			
                        print("Quantification for: ", maskName[currCell]);
						print("Cell no.: ", currCell+1, " / ", maskName.length);

						cellMaskLoc = TCSDir + "Cell Masks/" + maskName[currCell];
		
						//oldParams is a list of the parameters we measure using the normal measurements function in
						//imageJ
						oldParams = newArray("Analysed", "Perimeter", "Cell Spread", "Eccentricity", 
													"Roundness", "Soma Size", "Mask Size"); 

						//skelNames is a list of the parameters we measure on a skeletonised image in imageJ
						skelNames = newArray("# Branches", "# Junctions", "# End-point voxels", "# Junction voxels", 
						"# Slab voxels", "Average Branch Length", "# Triple points", "# Quadruple points", 
						"Maximum Branch Length", "Longest Shortest Path", "SkelArea");

						valuesToRecord = Array.concat(oldParams, skelNames);

						////////
						////////
						////////

						//This code we can paste later on - will be to update the table and relevant column names
						cellParameterTable = TCSDir + "Cell Parameters.csv";

						//Retrieving the status of each mask we need to generate for the current substack (and TCS)
						print("Retrieving cell parameters");

						if(File.exists(cellParameterTable) != 1) {

						}

						////////
						////////
						////////

						//We're here
							
						//If we haven't already copied the cell to the fracLac folder, do so
						if(File.exists(fracLacPath + "TCS" + toString(currentLoopValues[0]) +  imageNames[0] + maskDirFiles[i0]) == 0) {
							File.copy(storageFoldersArray[3] + maskDirFiles[i0], fracLacPath + "TCS" + toString(currentLoopValues[0]) +  imageNames[0] + maskDirFiles[i0]);
						}
							
							//Get out our skeleton values
							open(storageFoldersArray[3] + maskDirFiles[i0]);
							getDimensions(maskWidth, maskHeight, maskChannels, maskSlices, maskFrames);

							//Set calibration to pixels
							run("Properties...", "channels="+maskChannels+" slices="+maskSlices+" frames="+maskFrames+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
							rename("Test");

							run("Clear Results");
							
							//Skeletonise the image then get out the measures associated with the skelNames array from earlier
							run("Duplicate...", " ");
							run("Invert");
							run("Skeletonize (2D/3D)");
							run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] calculate");
							
							//If we're getting out length, we measure the number of pixels in the skeleton
							storeValues = newArray(skelNames.length);
							for(i1 = 0; i1< skelNames.length; i1++) {
								if(i1 < skelNames.length-1) {
								storeValues[i1] = getResult(skelNames[i1], 0);
								} else {
									selectWindow("Test-1");
									run("Invert");
									run("Create Selection");
									getRawStatistics(nPixels);
									storeValues[i1] = nPixels;
									run("Select None");
								}
							}
							run("Clear Results");

							//Close images we don't need anymore
							toClose = newArray("Longest shortest paths", "Tagged skeleton", "Test-1");
							for(i1 = 0; i1< toClose.length; i1++) {
								if(isOpen(toClose[i1])==1) {
								selectWindow(toClose[i1]);
								run("Close");
								}
							}
							
							//Select our non skeletonised image, get its perim, circul, AR, and area
							selectWindow("Test");
							rename(maskDirFiles[i0]);
							run("Create Selection");
							roiManager("add");
							List.setMeasurements;
		
							resultsStrings = newArray("Perim.", "Circ.", "AR", "Area");
							currentLoopIndices = newArray(1,4,3,6);
		
							for(i1=0; i1<resultsStrings.length; i1++) {
								currentMaskValues[(currentLoopIndices[i1])] = List.getValue(resultsStrings[i1]);
							}
		
							run("Select None");
							run("Invert");
							run("Points from Mask");
				
							//This bit is used to calculate the leftmost, rightmost, bottommost, and topmost parts of the mask
							//We then calculate the average distance between the centre of mass of the mask and these points
							//for our measure of cell spread
		
							//Get the selection coordinates of our mask
							getSelectionCoordinates(x, y);
		
							Array.getStatistics(x, xMin, xMax, mean, stdDev);
							Array.getStatistics(y, yMin, yMax, mean, stdDev);
		
							valuesToMatch = newArray(xMax, xMin, yMax, yMin);
		
							xAndYPoints = newArray(xMax, 0, xMin, 0, 0, yMax, 0, yMin);
							//[0] and [1] are highest x with y (rightmost), [2] and [3] are lowest x with y (leftmost), 
							//[4] and [5] are x and highest y (topmost) [7] and [8] are x with lowest y (bottommost)
		
							for(i1=0; i1<valuesToMatch.length; i1++) {	
								associatedValues = newArray(1);
								arrayToConcat = newArray(1);
								for(i2=0; i2<x.length; i2++) {
									matched = false;
									if(i1<2) {
										if(x[i2] == valuesToMatch[i1]) {
											associatedValues[associatedValues.length-1] = y[i2];
											matched = true;
										}
									} else {
										if(y[i2] == valuesToMatch[i1]) {
											associatedValues[associatedValues.length-1] = x[i2];
											matched = true;
										}
									}
									if(matched == true){
										//setBatchMode("exit and display");
										//Array.show("test", associatedValues);
										//waitForUser("");
										associatedValues = Array.concat(associatedValues, arrayToConcat);
									}	
								}
		
								finalList = newArray(1);
								finalList = removeZeros(associatedValues, finalList);
								
								Array.getStatistics(finalList, asMin, asMax, asMean, asStdDev);
		
								if(i1<2) {
									xAndYPoints[(i1*2)+1] = round(asMean);
								} else {
									xAndYPoints[(i1*2)] = round(asMean);
								}
							}
						
							open(storageFoldersArray[4]+"Local region for "+ substring(maskDirFiles[i0], indexOf(maskDirFiles[i0],"Substack")));
							LRImage = getTitle();
							selectWindow(LRImage);
							getDimensions(LRwidth, LRheight, LRchannels, LRslices, LRframes);
				
							//Calibrate to pixels so we can get the right values when we make points on our image as the previously generated variables are all
							//calibrated in pixels
							selectWindow(LRImage);
							run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
							roiManager("select", 0);
							List.setMeasurements;
		
							resultsStrings = newArray("XM", "YM");
							centresOfMass = newArray(2);
		
							for(i1=0; i1<resultsStrings.length; i1++) {
								centresOfMass[i1] = List.getValue(resultsStrings[i1]);
							}
		
							run("Select None");
							distances = newArray(4);
							//[0] is distance to the right, [1] is to the left, [2] is the top, [3] is the bottom
		
							for(i1=0; i1<4; i1++) {
								xToCheck = xAndYPoints[(i1*2)];
								yToCheck = xAndYPoints[(i1*2)+1];
		
								xDistance = abs(xToCheck-centresOfMass[0]);
								yDistance = abs(yToCheck-centresOfMass[1]);
		
								distances[i1] = sqrt((pow(xDistance,2) + pow(yDistance,2)));
		
								makeLine(centresOfMass[0], centresOfMass[1],  xAndYPoints[(i1*2)], xAndYPoints[(i1*2)+1]);
								Roi.setStrokeColor("red");
								roiManager("add");
							}
		
							//Store the average distance from the centre of mass to the xtremeties
							Array.getStatistics(distances, disMin, disMax, disMean, disStdDev);
							currentMaskValues[2] = disMean;
							
							run("Select None");
				
							//This is saving an image to show where the lines and centre are
							selectWindow(LRImage);
							run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
							roiManager("show all without labels");
							run("Flatten");
							selectWindow(LRImage);
							saveAs("tiff", storageFoldersArray[5]+"Extrema for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")));
				
							//Here we open the soma mask for the cell in question, and get its size
							oldxCoord = parseInt(substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "x ")+2, indexOf(maskDirFiles[i0], "y")-1));
							oldyCoord = parseInt(substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "y ")+2, indexOf(maskDirFiles[i0], ".tif")-1));
							oldSubstackLoc = substring(maskDirFiles[i0], indexOf(maskDirFiles[i0], "Substack"), indexOf(maskDirFiles[i0], "x"));
							adjustBy = newArray(0,0);
							if(File.exists(storageFoldersArray[2]+"Candidate Soma Mask for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")))==0) {
								//waitForUser("doesn't exist");
								for(i1 = 0; i1<somaFiles.length; i1++) {
									newxCoord = parseInt(substring(somaFiles[i1], indexOf(somaFiles[i1], "x ")+2, indexOf(somaFiles[i1], "y")-1));
									newyCoord = parseInt(substring(somaFiles[i1], indexOf(somaFiles[i1], "y ")+2, indexOf(somaFiles[i1], ".tif")-1));
									newsubstackLoc = substring(somaFiles[i1], indexOf(somaFiles[i1], "Substack"), indexOf(somaFiles[i1], "x"));
									if(abs(oldxCoord-newxCoord) <= 10 && abs(oldyCoord-newyCoord) <= 10 && newsubstackLoc == oldSubstackLoc) {
										adjustBy[0] = newxCoord-oldxCoord;
										adjustBy[1] = newyCoord-oldyCoord;
										//print(maskDirFiles[i0]);
										//print(somaFiles[i1]);
										open(storageFoldersArray[2] + somaFiles[i1]);
									}
								}
							} else {
								open(storageFoldersArray[2]+"Candidate Soma Mask for "+ substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack")));
							}
							rename("Soma");
							run("Properties...", "channels="+LRchannels+" slices="+LRslices+" frames="+LRframes+" unit=pixels pixel_width=1 pixel_height=1 voxel_depth=1");
							run("Create Selection");
							List.setMeasurements;
		
							resultsToGet = newArray("Area", "XM", "YM");
							resultsToOutput = newArray(3);
							//[0] is soma area, [1] is xMass, [2] is yMass
	
							for(i1=0; i1<3; i1++) {
								resultsToOutput[i1] = List.getValue(resultsToGet[i1]);
								//print(resultsToOutput[i1]);
							}
	
							currentMaskValues[5] = resultsToOutput[0];
				
							//We then find the centre of mass of the soma, and the radius of the soma (on average)
							//so that we can use the point and the radius to calculate a sholl analysis on the cell masks
							//starting from the edge of the soma
							//startradius=sqrt((currentMaskValues[5]*(iniTextValuesMicrons[1]/PI);
	
							startradius=sqrt((currentMaskValues[5]*pow(iniTextValuesMicrons[1], 2))/PI);
				
							//Here we run the sholl analysis using the point, the radius, and ending at the ending radius of the local region
							//We also output all the semi-log, log-log, linear, and linear-norm plots of the number of intersections at various distances
							//The normalisation is done using the area of the mask
							//Results are saved in the results folder
							roiManager("show none");
		
							selectWindow(maskDirFiles[i0]);
							run("Select None");
							makePoint(resultsToOutput[1]+adjustBy[0], resultsToOutput[2]+adjustBy[1]);

							//if(adjustBy[0] != 0 || adjustBy[1] != 0) {
								//print(resultsToOutput[1], resultsToOutput[2]);
								//print(adjustBy[0], adjustBy[1]);
								//setBatchMode("exit and display");
								//waitForUser("");
								//setBatchMode(true);
							//}
							
							run("Properties...", "channels="+maskChannels+" slices="+maskSlices+" frames="+maskFrames+" unit=um pixel_width="+iniTextValuesMicrons[0]+" pixel_height="+iniTextValuesMicrons[1]+" voxel_depth="+iniTextValuesMicrons[2]+"");
							run("Sholl Analysis...", "starting="+startradius+" ending="+LRSize+" radius_step=0 enclosing=1 #_primary=0 infer fit linear polynomial=[Best fitting degree] linear-norm semi-log log-log normalizer=Area create save directory=["+storageFoldersArray[5]+"] do");

							saveAs("Results", storageFoldersArray[5]+substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack"), indexOf(maskDirFiles[i0], ".tif")) + ".csv");
							selectWindow(substring(maskDirFiles[i0], indexOf(toLowerCase(maskDirFiles[i0]), "substack"), indexOf(maskDirFiles[i0], ".tif")) + ".csv");
							run("Close");
							run("Clear Results");
		
							Housekeeping();
	
					
							//Set the fact we've analysed the cell to 1 (true)
							currentMaskValues[0] = 1;

							//Concatenate the measured values together, with the info about the cell
							newValsOne = Array.concat(currentMaskValues, storeValues);
							toAdd = newArray(substackLoc[i0], imageNames[3], currentLoopValues[0], cellName[i0]);
							newVals = Array.concat(newValsOne, toAdd);

							//Here we update and save our cell parameters table
							selectWindow("Cell Parameters");
							for(i1 = 0; i1<tableLabels.length; i1++) {
								if(i1 == 18 || i1 == 19 || i1 == 21) {
									stringValue = newVals[i1];
									Table.set(tableLabels[i1], rowToAdd, stringValue);
								} else if (i1==1 || i1==2 || i1 == 12 || i1 == 15 || i1 == 16) {
									numberToStore = newVals[i1] * iniTextValuesMicrons[0];
									Table.set(tableLabels[i1], rowToAdd, numberToStore);
								} else if (i1==5 || i1==6 || i1 == 17) {
									numberToStore = newVals[i1] * pow(iniTextValuesMicrons[0],2);
									Table.set(tableLabels[i1], rowToAdd, numberToStore);
								} else {
									Table.set(tableLabels[i1], rowToAdd, newVals[i1]);
								}
							}
							Table.update;
							rowToAdd++;
						
						}	
					
					}	
	
					//Indicate that this TCS has been analysed
					currentLoopValues[3] = 1;
		
					//Update and save our TCS analysis table
					selectWindow("TCS Status");
					for(i0=0; i0<TCSColumns.length; i0++) {
						Table.set(TCSColumns[i0], TCSLoops, currentLoopValues[i0]);
					}
	
					selectWindow("Cell Parameters");
					Table.update;
					Table.save(TCSDir+"Cell Parameters.csv");
					currParam = Table.title;
					Table.rename(currParam, "Cell Parameters");
					
				}
		
			}

			selectWindow("TCS Status");
			Table.save(directories[1]+imageNames[3]+"/TCS Status.csv");
			currTCSTitle = Table.title;
			Table.rename(currTCSTitle, "TCS Status");
			
		}
	}
}
print("Morphological analysis complete");