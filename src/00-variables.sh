# Variables

# Azure Container Registry
prefix="Dariusz"
acrName="${prefix}Registry"
acrResourceGrougName="${prefix}RG"
location="eastus"

# Python Files
docAppFile="doc.py"
chatAppFile="chat.py"

# Docker Images
docImageName="doc"
chatImageName="chat"
tag="v1"
port="8000"

# Arrays
images=($docImageName $chatImageName)
filenames=($docAppFile $chatAppFile)