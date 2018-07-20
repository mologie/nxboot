# Release Checklist

1. Test the changes
2. Change the version number in Xcode
3. Increment the build number in Xcode
4. Ensure that everything is committed
5. Create a tag name schema `vX.Y.Z`
6. Run `./build.sh`
7. Install on a testing device (`./install_singetail.sh`) and make sure the DEB works
8. Update the changelog in the homepage repository
9. If nxboot CLI tool changed: Sign `DerivedData/bin/nxboot` binary, upload the binary and sig file to AWS, update the version in index.html
10. Ensure Cydia depiction and homepage changes are committed and pushed
11. Upload the new dSYM ZIP file from `dist/` to AppCenter
12. Copy the DEB file to the release repository
13. Run `./PackagesUpdate.sh` in the release repository, then commit and push
