// Macro for ImageJ - to plot radially arranged line profiles (specific xyz)
// Author: John Eykelenboom, 2025
//
// At the start of the script the user defines:
// - the X coordinate
// - the Y coordinate
// - the slice number (of the .dv file opened in ImageJ as consecutive images)
// - the pixel size (in microns e.g. for 1x1 bin, scMOS camera pixel size is 0.0645µm)
// This enables specifying the centre of the cell (using Imaris coordinates) and slice 
// which maybe less error prone than correcting the script each time
//
// The script saves a .csv file that:
// - contains the intensities along the lines with them labelled according to the angle of the line (e.g. Y0, Y10, Y20 etc.)
// - the file will be named with the same name as the opened file with the x, y and stack numbers appended at the end
// - it will save to a user specified location (which will be "printed" on the screen after the process is complete
// N.B. unfortunately there are white spaces between rows but it was hard to remove these!
//


// Ask the user to input the central coordinates
xc = getNumber("Enter X coordinate of the centre:", 100);
yc = getNumber("Enter Y coordinate of the centre:", 100);
// Ask the user to input the slice number to draw on
sliceNumber = getNumber("Enter the image slice number:", 1);
// Ask the user to define pixel size (microns per pixel)
pixelSize = getNumber("Enter pixel size (microns per pixel):", 0.0645);
// Set the image slice to the specified one
setSlice(sliceNumber);
// Get the image file name (without path and extension)
imageFileName = getTitle();
// Define parameters
radius = 180; // Length of the radiating lines (in pixels)
angleStep = 10; // Angle step in degrees
// Create a new ROI Manager
roiManager("reset");
// Generate the dynamic file name based on the image name, x, y coordinates, and slice number
savePath = getDirectory("Choose a directory to save") + imageFileName + "_" + xc + "_" + yc + "_slice" + sliceNumber + ".csv";
// Prepare header row: "Distance (X), Y1, Y2, Y3, ..., Y35"
header = "Distance (X) (microns)";
for (angle = 0; angle < 360; angle += angleStep) {
header += ",Y" + angle;
}
File.append(header + "\n", savePath);
// Extract and save intensity profiles for each line
profileLengths = newArray(); // Store profile lengths to determine X distances
for (angle = 0; angle < 360; angle += angleStep) {
// Convert angle to radians
radians = -angle * PI / 180; // Negative sign for correct direction
// Compute line endpoints
xEnd = xc + radius * cos(radians);
yEnd = yc + radius * sin(radians);
// Draw the line
run("Line Width...", "line=20");
makeLine(xc, yc, xEnd, yEnd);
// Add the line to the ROI Manager
roiManager("Add");
// Get the profile (intensity values along the line)
profile = getProfile();
// Store the profile length
profileLengths[angle / angleStep] = lengthOf(profile);
}
// Find maximum profile length to ensure all rows have the same X values
maxProfileLength = 0;
for (i = 0; i < lengthOf(profileLengths); i++) {
if (profileLengths[i] > maxProfileLength) {
maxProfileLength = profileLengths[i];
}
}
// Generate distance (X) values in microns
xValues = newArray(maxProfileLength);
for (i = 0; i < maxProfileLength; i++) {
xValues[i] = i * pixelSize; // Convert pixels to microns
}
// Write intensity values row by row
for (i = 0; i < maxProfileLength; i++) {
row = "" + xValues[i]; // Start with distance value (in microns)
for (angle = 0; angle < 360; angle += angleStep) {
// Get profile for this line
roiManager("Select", angle / angleStep);
profile = getProfile();
// Add intensity value if it exists, otherwise add NaN
if (i < lengthOf(profile)) {
row += "," + profile[i];
} else {
row += ",NaN";
}
}
// Save row to CSV
File.append(row + "\n", savePath);
}
// Update display
updateDisplay();
// Display the lines for the user
roiManager("Show All with labels");
roiManager("Multi Plot");
// Notify user that file is saved
print("CSV file saved to: " + savePath);
I made another macro to save an image of the the position of the radii. It can be ran immediately after the above macro (after first selecting the image containing the regions of interest):
// Ask the user for a slice number
slices = getNumber("Enter slice number to duplicate:", 1);
// Get the original image name
origTitle = getTitle();
// Duplicate the selected slice
run("Duplicate...", "duplicate range=" + slices + "-" + slices);
// in this workflow it ensures that the regions that were defined in the previous macro are carried across and seen in the newly duplicated image before saving
roiManager("Show None");
roiManager("Show All");
// Flatten the image to include the overlay
run("Flatten");
// Ask the user where to save the image
savePath = getDirectory("Choose Save Location");
// Construct the new filename with original title + slice number
newFileName = origTitle + " stack " + slices + " overlay.png";
// Save as PNG in the selected directory
saveAs("PNG", savePath + newFileName);
// Return focus to the original image
selectWindow(origTitle);
