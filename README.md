# MEAL-AI

## Running the Search
1. Clone the repository and open the Xcode project:
   ```bash
   git clone <this repo>
   cd MEAL-AI
   open "MEAL AI.xcodeproj"
   ```
2. Select the **MEAL AI** scheme and build/run on a device or simulator.
3. Tap the search icon in the app, enter a food, and review the results.

## Configuring the iAPS Shortcut
1. On your iPhone, open the **Shortcuts** app.
2. Import the **MEAL-AI iAPS** shortcut included in this repository.
3. When prompted, set the server URL and other options to match your setup.
4. The shortcut sends macronutrient data to iAPS in JSON form, for example:

```json
{"carbs": 25, "protein": 5, "fat": 10}
```

5. Save the shortcut and run it after selecting a food to share the data with iAPS.

## Notes
- Ensure your device has the required permissions and network access.
- This project is for personal experimentation; use at your own risk.
