# Soccer Player Timer App

A simple Swift Playgrounds app to track **minutes and seconds played** by kids on a soccer team.  
The app was built to make it easy for coaches (or parents) to manage substitutions and ensure fair playtime.

---

## 📱 Features
- Add players with **first name, last name, and number** (number optional).
- Track **time on the field vs time on the bench** for each player.
- Countdown game clock with adjustable game length.
- Pause/resume the timer at halftime or for breaks.
- Assign players to positions (default is **Bench**).
- Designed to run directly in **Swift Playgrounds** on iPad or Mac.

---

## Requirements
- macOS with [Swift Playgrounds](https://apps.apple.com/us/app/swift-playgrounds/id908519492?mt=12)  
  or iPad with Swift Playgrounds installed.
- Swift 5.x

---

## Getting Started
1. Clone this repository:
   ```bash
   git clone https://github.com/<your-username>/<repo-name>.git
2. Open the project:
- If using macOS: double-click SoccerApp.swiftpm to open in Swift Playgrounds.
- If using iPad: import the .swiftpm into Playgrounds via Files or AirDrop.
3. Run the app in Playgrounds and start tracking game time.


## Project Structure
 * SoccerApp.swiftpm/ → Swift Playgrounds project package
 ** Contains ContentView.swift, GameManager.swift, and player/position models.

## Future Improvements
- Export playtime reports per player.
- Add ability to save/load rosters.
- Simple UI polish for iPad screen sizes.

##License
This project is licensed under the MIT License — feel free to use, modify, and share.
