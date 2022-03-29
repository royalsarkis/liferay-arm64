# Running Liferay docker images for Arm64
Official Liferay Docker images only support AMD processor. So, the **Beorn technologies** team has therefore developed a script to build images supporting the ARM64 processor.

New images will be built the same way official images are built, but they are based on images that support the ARM64 processor.

# Usage
* Clone this repository
* run chmod +x ./buildLiferay.sh
* run ./buildLiferay.sh and choose the liferay version you need to build
