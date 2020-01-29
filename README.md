# Wall-E

A bot that monitors and manages your pull requests by ensuring they are merged when they're ready and don't stack up in your repository 🤓

### Motivation

Pull Requests are conceptually asynchronous and they go through a series of iterations until they are finally ready to be merged which not always happens when we are expecting, we can be waiting for CI to test it, waiting for a review, ... 

That can lead to the pull request staying in the repository for longer than it needs to be and potentially stacking up with other pull requests making the integrations more time consuming and challenging.

### The notion of ready

Pull Requests should meet a specific set of criteria before being merged.

- Be in sync with the base branch
- Be reviewed and approved by a minimum number of reviewers
- Have all checks passing

Depending on the workflow of each team some of them may be disabled to suit their needs.

### How?

👷‍♀️ **WIP, come back later** 👷‍♂️

![](https://media.giphy.com/media/26ybvJNaZZKpPONEc/giphy.gif)
### Client app (Menu Icon)

This repository also comes with a Client app that allows you to quickly check the state of the Merge Bot queue from the menu bar.

To install the client app:

 - Build `WallEView/WallEView.xcodeproj` in Xcode and copy the app from build products directory to your applications directory, or download the app attached to the [latest GitHub release](https://github.com/babylonhealth/Wall-E/releases)
 - Run `defaults write com.babylonhealth.WallEView Host <application address>` to set the url to the app
 - Launch the app and enjoy.

 Once the app has been launched, a new icon should appear on your menubar (next to clock, wifi, anc similar menubar icons).
 
 When opening the menu item by clicking on its icon, you can select a branch to see its associated merge queue.
 
 To kill the app and remove the menubar icon, right-click on the icon and select "Close".

Iconography © https://dribbble.com/shots/2772860-WALL-E-Movie-Icons

### Debugging

Using [the ngrok tool](https://dashboard.ngrok.com/get-started) you can run the app locally and still get all incoming events from GitHub webhooks.

- setup ngrok and start it, it will print out the public address from which all requests will be redirected to your localhost, i.e. https://randomnumber.ngrok.io

- add a webhook to the repository where you want to test the app (https://github.com/babylonhealth/walle-debug for use by Babylon team members):
 - set webhook url to https://randomnumber.ngrok.io/github
 - set content type to `application/json`
 - set a webhook secret to some random value
 - enabled status and pull request events

Then you can start the app locally setting its environment variables to point to the testing repository. You need to set `GITHUB_WEBHOOK_SECRET`, `GITHUB_TOKEN`, `GITHUB_ORGANIZATION` and `GITHUB_REPOSITORY` as environment variables in the `Run` scheme. You also need to set few other environment variables: `MERGE_LABEL` and `TOP_PRIORITY_LABELS`
