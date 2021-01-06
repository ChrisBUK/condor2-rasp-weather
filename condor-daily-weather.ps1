## Helper Functions

# Help strip out non forecast data
function Is-Numeric ($Value) {
    return $Value -match "^[\d\.]+$"
}

# Get min and max values across the whole day
function getMinMax($set) {
    $min = 99999; $max = -99999; 
    
    foreach ($value in $set) {
   
        if (Is-Numeric($value[0].value)) {
            if ($value[0].value -ge $max) { 
                $max = $value[0].value
            }

            if ($value[0].value -le $min) { 
                $min = $value[0].value
            }   
        }
    }

    $variance = $max-$min

    return $min,$max,$variance;
}


### Geographical location for which we want RASP data
$weatherLat = "54.2288"
$weatherLong = "-1.20967"

### Defaults to assume for when we don't have data, and the vars we will use to create the Weather data for Condor

# The wind direction below the boundary layer, in degrees.
$condorSurfaceWindDir = 0

# The wind speed below the boundary layer, in MPH.
$condorSurfaceWindSpeed = 0

# The wind speed above the boundary layer, for wave generation, in MPH.
$condorUpperWindSpeed = 0

# The wind direction variation below the boundary layer.
$condorWindDirVariation = 0

# The wind speed variation below the boundary layer.
$condorWindSpeedVariation = 0

# The general turbulence caused by wind shear
$condorWindTurbulence = 0

# The base temperature at the time of calculating the map. It only changes within the variance, and goes into cloudbase calcs.
$condorThermalsTemp = 0

# The variation in temperature which would indicate a variable cloud base.
$condorThermalsTempVariation = 0

# The Dew Point at the time of calculating the map. It doesn't change during flight AFAIK.
$condorThermalsDewPoint = 0

# How strong the thermals are 
$condorThermalsStrength = 0

# How variable the strength of the thermals are
$condorThermalsStrengthVariation = 0

# The inversion height which appears to define the maximum for the cloud tops.
$condorThermalsInversionHeight = 0

# How wide the thermals are 
$condorThermalsWidth = 0

# How variable the width of the thermals are
$condorThermalsWidthVariation = 0

# The general amount of thermal activity you find over hills and mountains AFAIK
$condorThermalsActivity = 0;

# How turbulent it is within a thermal.
$condorThermalsTurbulence = 0;

# The general amount of activity you find over the flatlands 
$condorThermalsFlatsActivity = 0;

# The chance of clouds streeting from 0 (no) to ? (high).
$condorThermalsStreeting = 0

# This appears to set the wave-length, according to how the GUI represents it
$condorWavesStability = 0

# This appears to set the formation of Lenticulars according to how the GUI represents it.
$condorWavesMoisture = 0

# High clouds in eighths - Think this is basically cosmetic.
$condorHighCloudsCoverage = 0

# Pressure (mb) - doesn't do anything in the sim AFAIK, you can't normally set this in the GUI
$condorPressure = 1013.2

# Should leave set to zero or it will probably override everything.
$condorWeatherPreset = 0 

# Randomises within the bounds of the settings (I think) but for a fair comp/ladder should be 0, everyone should have the same.
$condorRandomizeWeatherOnEachFlight = 0 


### Setting up the RASP API call
$weatherParams = "sfcwinddir sfcwindspd blwindspd sfctemp sfcdewpt zsfclcl bsratio hbl blwindshear blcloudpct stars               hwcrit wstar rain1 sfctemp hwcrit sfcsunpct dbl bltopvariab sfcshf dwcrit bsratio sfcdewpt mslpress zsfclcldif blwindshear wblmaxmin zsfclcl zblcldif blcwbase blcloudpct hbl cape".replace(" ","%20")
#$weatherParams = "";

$raspAPI = "http://rasp.mrsap.org/cgi-bin/get_rasp_blipspot.cgi?region=UK12&grid=d2&day=0&lat="+$weatherLat+"&lon="+$weatherLong+"&width=2000&height=2000&linfo=1&param="+$weatherParams+"&format=JSON";

### Make API call and get the data we want
$raspRequest = Invoke-WebRequest -Uri $raspAPI
$raspData= $raspRequest.Content | ConvertFrom-Json

#echo $raspData.get_rasp_blipspot_results.Results[0].values


### Perform any conversions and calculations on the data

# Wind Dir
$condorSurfaceWindDir   = $raspData.get_rasp_blipspot_results.Results[0].values[10].value

# Wind Dir Variation (0 None - 3 High)
$windDirVar = getMinMax($raspData.get_rasp_blipspot_results.Results[0].values)
if ($windDirVar[2] -lt 5) { $condorWindDirVariation = 0 }
if ($windDirVar[2] -ge 5) { $condorWindDirVariation = 1 }
if ($windDirVar[2] -ge 10) { $condorWindDirVariation = 2 }
if ($windDirVar[2] -ge 15) { $condorWindDirVariation = 3 }
if ($windDirVar[2] -ge 20) { $condorWindDirVariation = 4 }

# Wind Speed
$condorSurfaceWindSpeed = [math]::Round($raspData.get_rasp_blipspot_results.Results[1].values[10].value / 2, 2)

# Wind Speed Variation (0 None - 3 High)
$windSpdVar = getMinMax($raspData.get_rasp_blipspot_results.Results[1].values)
if ($windSpdVar[2] -lt 3) { $condorWindSpeedVariation = 0 }
if ($windSpdVar[2] -ge 3) { $condorWindSpeedVariation = 1 }
if ($windSpdVar[2] -ge 5) { $condorWindSpeedVariation = 2 }
if ($windSpdVar[2] -ge 8) { $condorWindSpeedVariation = 3 }

# Upper Wind Speed
$condorUpperWindSpeed   = [math]::Round($raspData.get_rasp_blipspot_results.Results[2].values[10].value / 2, 2)

# Max Temperature in the day
$temp = getMinMax($raspData.get_rasp_blipspot_results.Results[3].values)
$condorThermalsTemp     = [math]::Round($temp[1], 2)

# Lowest dew point in the day
$dew = getMinMax($raspData.get_rasp_blipspot_results.Results[4].values)
$condorThermalsDewPoint = [math]::Round($dew[0], 2)

# Cloudbase variation - based on the difference between RASPs lowest and highest Cu Base prediction
$cuBaseVar = getMinMax($raspData.get_rasp_blipspot_results.Results[5].values)
if ($cuBaseVar[2] -lt 200) { $condorThermalsTempVariation = 0 }
if ($cuBaseVar[2] -ge 400) { $condorThermalsTempVariation = 1 }
if ($cuBaseVar[2] -ge 600) { $condorThermalsTempVariation = 2 }
if ($cuBaseVar[2] -ge 800) { $condorThermalsTempVariation = 3 }
if ($cuBaseVar[2] -ge 1000) { $condorThermalsTempVariation = 4 }

# Thermal Width - using Bouyancy/Shear ratio, higher BS means narrower thermals? (0=v.narrow, 4=v.wide) 
$bsRatio = $raspData.get_rasp_blipspot_results.Results[6]
if ($bsRatio[2] -lt 5) { $condorThermalsWidth = 4 } 
if ($bsRatio[2] -ge 10) { $condorThermalsWidth = 3 }
if ($bsRatio[2] -ge 15) { $condorThermalsWidth = 2 }
if ($bsRatio[2] -ge 20) { $condorThermalsWidth = 1 }
if ($bsRatio[2] -ge 25) { $condorThermalsWidth = 0 }

# Thermal Width Variation - use BS Ratio variation across a day to come up with a value
$bsRatio = getMinMax($raspData.get_rasp_blipspot_results.Results[6].values)
if ($bsRatio[2] -lt 2) { $condorThermalsWidthVariation = 0 }
if ($bsRatio[2] -ge 3) { $condorThermalsWidthVariation = 1 }
if ($bsRatio[2] -ge 4) { $condorThermalsWidthVariation = 2 }
if ($bsRatio[2] -ge 5) { $condorThermalsWidthVariation = 3 }
if ($bsRatio[2] -ge 6) { $condorThermalsWidthVariation = 4 }

# Inversion Height - use highest BL Top to predict height of cloud tops.
$blTop = getMinMax($raspData.get_rasp_blipspot_results.Results[7].values)
$condorThermalsInversionHeight = [math]::Round($blTop[1] / 3.281, 0)

# Wind Turbulence (0 none, 4 Severe) =  Use BL wind shear? 
$blShear = $raspData.get_rasp_blipspot_results.Results[8].values[10].value

if ($blShear[2] -lt 2) { $condorWindTurbulence = 0 }
if ($blShear[2] -ge 4) { $condorWindTurbulence = 1 }
if ($blShear[2] -ge 6) { $condorWindTurbulence = 2 }
if ($blShear[2] -ge 8) { $condorWindTurbulence = 3 }
if ($blShear[2] -ge 10) { $condorWindTurbulence = 4 }

# High Cloud Cover 
$hcCover = $raspData.get_rasp_blipspot_results.Results[9].values[10].value

if ($hcCover[2] -lt 12.5) { $condorHighCloudsCoverage = 0 }
if ($hcCover[2] -ge 12.5) { $condorHighCloudsCoverage = 1 }
if ($hcCover[2] -ge 25.0) { $condorHighCloudsCoverage = 2 }
if ($hcCover[2] -ge 37.5) { $condorHighCloudsCoverage = 3 }
if ($hcCover[2] -ge 50) { $condorHighCloudsCoverage = 4 }
if ($hcCover[2] -ge 62.5) { $condorHighCloudsCoverage = 5 }
if ($hcCover[2] -ge 75) { $condorHighCloudsCoverage = 6 }
if ($hcCover[2] -ge 87.5) { $condorHighCloudsCoverage = 7 }
if ($hcCover[2] -ge 95 ) { $condorHighCloudsCoverage = 8 }


# Thermal Strength - use star rating? (0=V.Weak - 4=V.Strong)
$stars = $raspData.get_rasp_blipspot_results.Results[10].values[10].value
if ($stars[2] -eq 0) { $condorThermalsStrength = 0 }
if ($stars[2] -eq 1) { $condorThermalsStrength = 1 }
if ($stars[2] -eq 2) { $condorThermalsStrength = 2 }
if ($stars[2] -eq 3) { $condorThermalsStrength = 2 }
if ($stars[2] -eq 4) { $condorThermalsStrength = 3 }
if ($stars[2] -eq 5) { $condorThermalsStrength = 4 }

# Thermal Strength Variation - ?
$condorThermalsStrengthVariation = 2

# Thermal Activity on the hills (0 none, 4 high)- ?
$condorThermalsActivity = 2

# Thermal Turbulence (0 none, 4 Severe) - ?
$condorThermalsTurbulence = 1

# Thermnal Activity on the flats (0 very low, 4 high) - ?
$condorThermalsFlatsActivity = 2

# Streeting (0 none - 3 high)
$condorThermalsStreeting = 1

# Waves (Stability 0-10, Moisture 0-8) 
$condorWavesStability = 4
$condorWavesMoisture = 4

# Pressure (mb) - doesn't do anything in the sim AFAIK, you can't normally set this in the GUI
$condorPressure = 1013.2

### Update the variables

echo "WindDir=$condorSurfaceWindDir"
echo "WindSpeed=$condorSurfaceWindSpeed"
echo "WindUpperSpeed=$condorUpperWindSpeed"
echo "WindDirVariation=$condorWindDirVariation"
echo "WindSpeedVariation=$condorWindSpeedVariation"
echo "WindTurbulence=$condorWindTurbulence"
echo "ThermalsTemp=$condorThermalsTemp";
echo "ThermalsTempVariation=$condorThermalsTempVariation"
echo "ThermalsDew=$condorThermalsDewPoint"
echo "ThermalsStrength=$condorThermalsStrength"
echo "ThermalsStrengthVariation=$condorThermalsStrengthVariation"
echo "ThermalsInversionHeight=$condorThermalsInversionHeight"
echo "ThermalsWidth=$condorThermalsWidth"
echo "ThermalsWidthVariation=$condorThermalsWidthVariation"
echo "ThermalsActivity=$condorThermalsActivity"
echo "ThermalsTurbulence=$condorThermalsTurbulence"
echo "ThermalsFlatsActivity=$condorThermalsFlatsActivity"
echo "ThermalsStreeting=$condorThermalsStreeting"
echo "WavesStability=$condorWavesStability"
echo "WavesMoisture=$condorWavesMoisture"
echo "HighCloudsCoverage=$condorHighCloudsCoverage"
echo "Pressure=$condorPressure"

# We don't change these
echo "WeatherPreset=0"
echo "RandomizeWeatherOnEachFlight=0"


### Phase 1: Output the condor-fpl file friendly [weather] sections

### Phase 2: Replace the [weather] section in an existing FPL file with our generated one.


