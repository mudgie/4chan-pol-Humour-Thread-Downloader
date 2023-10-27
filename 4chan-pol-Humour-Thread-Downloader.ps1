$imagesDir = ".\Images\"
$hashesCsvFile = ".\Hashes.csv"
$threadsCsvFile = ".\Threads.csv"

# Create empty CSV files if they don't already exist
if (!(Test-Path $hashesCsvFile -PathType Leaf)) {
	New-Item -Name $hashesCsvFile -ItemType File | Out-Null
}
if (!(Test-Path $threadsCsvFile -PathType Leaf)) {
	New-Item -Name $threadsCsvFile -ItemType File | Out-Null
}

# Create images directory if it doesn't already exist
if (!(Test-Path $imagesDir)) {
    New-Item $imagesDir -ItemType Directory | Out-Null
}

# Scrape archive page for thread URLs
Write-Output "Scraping archived threads..."

$scrapedLinks = (Invoke-WebRequest -Uri 'https://boards.4chan.org/pol/archive').Links.Href
$regex = "/pol/thread/.*humo.*thread.*"
$allMatches = ($scrapedLinks | Select-String $regex -AllMatches).Matches

# Get thread numbers from URLs
$threads = foreach ($url in $allMatches){
    $url.Value -replace "[^0-9]"
}

$threadsCsv = Get-Content $threadsCsvFile
$hashesCsv = Get-Content $hashesCsvFile

foreach ($thread in $threads) {
	# Check the threads CSV and skip any that have already been processed
	if ($threadsCsv | Select-String -Pattern ".*$thread*") {
		Write-Output "Skipping already processed thread #${thread}..."
	}
	else {
		$threadUrl = "https://a.4cdn.org/pol/thread/" + $thread + ".json"
		$apiResponse = Invoke-RestMethod -Uri $threadUrl -Method GET
		$numberOfImages = $apiResponse.posts.images
		$subject = $apiResponse.posts.sub
		
		Write-Output "Downloading images/videos from thread #${thread}: ${subject}"

		foreach ($post in $apiResponse.posts) {
			# Ignore posts with no images/videos
			if (![string]::IsNullOrEmpty($post.tim)) {
				
				$md5 = $post.md5
				$md5Regex = $post.md5.replace("+","\+") # Escape '+' characters
				
				# Check the hashes CSV to see if image/video has already been downloaded to avoid duplicates
				if ($hashesCsv | Select-String -Pattern ".*$md5Regex*") {
					Write-output "Image/video $md5 found in existing hashes, skipping..."
				}
				else {
					Write-output "Image/video $md5 not found in existing hashes, downloading..." 
					$imageUrl = "https://i.4cdn.org/pol/" + $post.tim + $post.ext
					Start-BitsTransfer -Source $imageUrl -Destination $imagesDir -TransferType Download
					
					# Add file hash to CSV to skip it on next script run
					"{0}" -f $post.md5 | add-content -path $hashesCsvFile
				}
			}
		}
		
		# Add thread number to CSV to skip it on next script run
		"{0}" -f $thread | add-content -path $threadsCsvFile
	
		# Wait 1 second between API calls as per the rules
		Start-Sleep -Seconds 1
	}
}
