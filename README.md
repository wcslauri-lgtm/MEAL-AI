# MEAL-AI

Disclaimer

This project is not a medical device. It has not been approved, certified, or tested for medical use. It is a DIY (do-it-yourself) project intended solely for hobby and personal experimentation.

Use is at your own risk. The developers, contributors, and distributors make no warranties regarding the safety, accuracy, or functionality of this project and accept no liability for any direct, indirect, incidental, or consequential damages, injuries, illnesses, or other outcomes that may result from its use.

If you have any questions or concerns regarding your health or treatment, always consult a qualified healthcare professional.

## Shortcuts integration

MEAL-AI can send meal macronutrient estimates to an iAPS Shortcut. When enabled in settings, the app launches a Shortcut and passes a JSON dictionary containing the rounded gram values for carbohydrates, protein and fat:

```json
{"carbs": 10, "protein": 5, "fat": 3}
```

Inside the Shortcut use **Get Dictionary from Input** to read these values. Forward the `carbs`, `protein` and `fat` entries to iAPS using whatever actions your setup requires.
