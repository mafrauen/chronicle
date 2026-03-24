# Date Testing System for ToJo

## Overview

I've implemented a complete date override system that allows you to test the app with different dates in Xcode previews. This is essential for testing how weekly goals work across different weeks.

## How It Works

### 1. DateService (`DateService.swift`)

The `DateService` is an `@Observable` class that provides the "current" date throughout the app:

- **`now`** property: Returns the actual current date, or an overridden date if set
- **`overriddenDate`** property: Optional date that, when set, replaces the current date
- Injected via SwiftUI environment for easy access and override

### 2. Updated Views

The following views now use `DateService` instead of `Date()`:

- **`CurrentWeekView`**: Uses `dateService.now` to determine which week to display
  - Automatically reloads when the date changes
  - Saves with the overridden date
  
- **`AddAchievementView`**: Defaults the completion date to the current simulated date

### 3. Preview Testing UI

The new **"Date Testing"** preview includes:

- **Date Picker**: Select any date to simulate
- **Quick Action Buttons**:
  - "Today" - Reset to actual current date
  - "Next Week" - Jump forward one week
  - "Next Month" - Jump forward one month
- **Current Date Display**: Shows the simulated date
- **Sample Data**: Pre-populated with goals and achievements for testing

## Testing Workflow

### In Xcode Previews:

1. Run the "Date Testing" preview
2. Use the date picker at the top to select a future date
3. Navigate to "Weekly Goals"
4. Type some goals and watch them save
5. Change the date to next week
6. The goals should save and a new blank text field should appear
7. Go to "Past Weeks" to see your previously saved week

### Example Test Scenario:

```
1. Set date to "March 24, 2026" (this week)
   → Enter goals: "Ship feature X, Fix bug Y"
   
2. Set date to "March 31, 2026" (next week)
   → See a blank goal field
   → Enter new goals: "Review PRs, Write tests"
   
3. Set date to "April 7, 2026" (week after)
   → See another blank goal field
   
4. Navigate to "Past Weeks"
   → See all three weeks listed with their goals
```

## Using in Production

The `DateService` defaults to using the real current date when not overridden, so the production app will work normally. The override only affects previews where you explicitly set it.

## Future Enhancements

Possible additions:
- Add date override UI in debug builds (via Settings screen)
- Create test helpers for unit tests
- Add "jump to specific week" functionality
