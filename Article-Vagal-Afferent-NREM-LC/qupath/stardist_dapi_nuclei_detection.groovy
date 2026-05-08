
import qupath.ext.stardist.StarDist2D

// -------------------- USER-ADJUSTABLE PARAMETERS --------------------
def detectionThreshold = 0.2        // StarDist probability threshold
def pixelSizeMicrons  = 3.0         // Pixel size for detection (µm)
def detectionChannel  = 'DAPI'      // Nuclear channel
// -------------------------------------------------------------------

// Path to pretrained StarDist model (see README for download)
def pathModel = "dsb2018_heavy_augment.pb"

def stardist = StarDist2D.builder(pathModel)
        .threshold(detectionThreshold)
        .channels(detectionChannel)
        .normalizePercentiles(1, 99)
        .pixelSize(pixelSizeMicrons)
        .measureShape()
        .measureIntensity()
        .build()

// Run detection within selected parent objects (ROIs)
def imageData = getCurrentImageData()
def pathObjects = getSelectedObjects()

if (pathObjects.isEmpty()) {
    Dialogs.showErrorMessage("StarDist", "Please select a parent object!")
    return
}
