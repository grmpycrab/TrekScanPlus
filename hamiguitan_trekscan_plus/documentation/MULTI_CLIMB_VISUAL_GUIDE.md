# Multi-Climb Feature - Visual Guide

## User Interface Flow

### 1. Station Screen (Initial State)

```
┌────────────────────────────────────────┐
│ [⏱] Stations                        │
├────────────────────────────────────────┤
│                                        │
│ [Visited]  [Not Visited]              │
│  (3)        (12)                       │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Station A                        │  │
│ │ Difficulty: Hard  Elevation: 800m│  │
│ │ ✓ VISITED                        │  │
│ │                                  │  │
│ └──────────────────────────────────┘  │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Station B                        │  │
│ │ Difficulty: Medium  Elevation: 900m│
│ │ ✓ VISITED                        │  │
│ │                                  │  │
│ └──────────────────────────────────┘  │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Station C                        │  │
│ │ Difficulty: Hard  Elevation: 1050m │
│ │ ✓ VISITED                        │  │
│ │                                  │  │
│ └──────────────────────────────────┘  │
│                                        │
├────────────────────────────────────────┤
│                      [+ New Climb] FAB │
└────────────────────────────────────────┘
```

### 2. Create New Climb Dialog

```
┌────────────────────────────────────┐
│ Start New Climb                    │
├────────────────────────────────────┤
│                                    │
│ Climb Name                         │
│ ┌──────────────────────────────┐   │
│ │ [🏔] Morning Trek 2025_____│   │
│ └──────────────────────────────┘   │
│                                    │
│ Description (Optional)             │
│ ┌──────────────────────────────┐   │
│ │ [📝] Solo attempt with friends│  │
│ │                              │   │
│ │                              │   │
│ └──────────────────────────────┘   │
│                                    │
│          [Cancel]  [✓ Create]     │
│                                    │
└────────────────────────────────────┘
```

### 3. Station Screen with Active Climb

```
┌────────────────────────────────────────┐
│ [⏱] Stations                        │
├────────────────────────────────────────┤
│ ┌────────────────────────────────────┐ │
│ │ ● Morning Trek 2025                │ │
│ │ Stations: 2 | Duration: 1h 15m    │ │
│ │                                    │ │
│ │                          [▶ More] │ │
│ └────────────────────────────────────┘ │
│                                        │
│ [Visited]  [Not Visited]              │
│  (2)        (13)                       │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Station A                        │  │
│ │ Difficulty: Hard  Elevation: 800m│  │
│ │ ✓ VISITED                        │  │
│ │                                  │  │
│ └──────────────────────────────────┘  │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Station B                        │  │
│ │ Difficulty: Medium  Elevation: 900m│
│ │ ✓ VISITED                        │  │
│ │                                  │  │
│ └──────────────────────────────────┘  │
│                                        │
├────────────────────────────────────────┤
│                      [+ New Climb] FAB │
└────────────────────────────────────────┘

Live Banner:
- Shows climb name
- Counts stations visited in this session
- Shows elapsed time
- Tap to view detailed stats
- Updates automatically as stations are scanned
```

### 4. Climb Session Detail Screen

```
┌────────────────────────────────────────┐
│ [←] Morning Trek 2025                │
├────────────────────────────────────────┤
│                                        │
│ Morning Trek 2025       [COMPLETED] │
│ Solo attempt with friends              │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ [⏱] 1h 15m  │ [📍] 5 Stations  │  │
│ │ Duration     │ Count            │  │
│ ├──────────────────────────────────┤  │
│ │ [🏔] 850m    │ [📊] 1200m       │  │
│ │ Avg Elevation│ Total Gain       │  │
│ └──────────────────────────────────┘  │
│                                        │
│ Visited Stations                      │
│ ┌──────────────────────────────────┐  │
│ │ ① Station A              14:30   │  │
│ │ Elevation: 800m                  │  │
│ │ Distance: 2.5 km                 │  │
│ │                                  │  │
│ │ ─────────────────────────────    │  │
│ │                                  │  │
│ │ ② Station B              15:45   │  │
│ │ Elevation: 900m                  │  │
│ │ Distance: 3.2 km                 │  │
│ │ Time to next: 1h 15m             │  │
│ │                                  │  │
│ │ ─────────────────────────────    │  │
│ │                                  │  │
│ │ ③ Station C              16:50   │  │
│ │ Elevation: 950m                  │  │
│ │ Distance: 2.0 km                 │  │
│ │ Time from prev: 1h 05m           │  │
│ │                                  │  │
│ │ ─────────────────────────────    │  │
│ │                                  │  │
│ │ ④ Station D              17:30   │  │
│ │ Elevation: 1050m                 │  │
│ │ Distance: 1.5 km                 │  │
│ │ Time from prev: 40m              │  │
│ │                                  │  │
│ │ ─────────────────────────────    │  │
│ │                                  │  │
│ │ ⑤ Station E              18:15   │  │
│ │ Elevation: 1100m                 │  │
│ │ Distance: 1.8 km                 │  │
│ │ Time from prev: 45m              │  │
│ │                                  │  │
│ └──────────────────────────────────┘  │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Created: 21/1/2025 14:30        │  │
│ │ Started: 21/1/2025 14:30        │  │
│ │ Completed: 21/1/2025 18:15      │  │
│ └──────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

### 5. Climb History Screen - Ongoing Tab

```
┌────────────────────────────────────────┐
│ [←] My Climbs                         │
├────────────────────────────────────────┤
│ [Ongoing] [Completed]                 │
├────────────────────────────────────────┤
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Afternoon Challenge  [ONGOING] │  │
│ │ Testing new route               │  │
│ │ [📍] 3 stations | [⏱] 45m 30s   │  │
│ │ [🏔] 12.5 km                    │  │
│ │ Created: 21/1/2025              │  │
│ │                                 │  │
│ │          [▶ View Details]       │  │
│ └──────────────────────────────────┘  │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Summit Rush         [ONGOING]    │  │
│ │ No description                  │  │
│ │ [📍] 2 stations | [⏱] 32m 15s   │  │
│ │ [🏔] 8.3 km                     │  │
│ │ Created: 20/1/2025              │  │
│ │                                 │  │
│ │          [▶ View Details]       │  │
│ └──────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

### 6. Climb History Screen - Completed Tab

```
┌────────────────────────────────────────┐
│ [←] My Climbs                         │
├────────────────────────────────────────┤
│ [Ongoing] [Completed]                 │
├────────────────────────────────────────┤
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Morning Trek 2025    [COMPLETED] │  │
│ │ Solo attempt                    │  │
│ │ [📍] 5 stations | [⏱] 1h 15m    │  │
│ │ [🏔] 11.0 km                    │  │
│ │ Created: 21/1/2025              │  │
│ │                                 │  │
│ │          [▶ View Details]       │  │
│ └──────────────────────────────────┘  │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ First Attempt       [COMPLETED] │  │
│ │ Exploring with family            │  │
│ │ [📍] 4 stations | [⏱] 1h 08m    │  │
│ │ [🏔] 9.7 km                     │  │
│ │ Created: 19/1/2025              │  │
│ │                                 │  │
│ │          [▶ View Details]       │  │
│ └──────────────────────────────────┘  │
│                                        │
│ ┌──────────────────────────────────┐  │
│ │ Sunday Explorer     [COMPLETED] │  │
│ │ No description                  │  │
│ │ [📍] 3 stations | [⏱] 52m 30s   │  │
│ │ [🏔] 7.2 km                     │  │
│ │ Created: 18/1/2025              │  │
│ │                                 │  │
│ │          [▶ View Details]       │  │
│ └──────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

## Data Visualization

### Timeline of a Single Climb

```
14:30 ────────── Station A (800m) ────────────── 15:45
         45 min                    
         2.5 km           
                              
15:45 ────────── Station B (900m) ────────────── 16:50
         65 min                    
         3.2 km           
                              
16:50 ────────── Station C (950m) ────────────── 17:30
         40 min                    
         2.0 km           
                              
17:30 ────────── Station D (1050m) ──────────── 18:15
         45 min                    
         1.5 km           
                              
18:15 ────────── Station E (1100m)
         1.8 km           

TOTAL: 1h 45m | 5 Stations | 11.0 km | Avg Elevation: 960m
```

### Statistics Dashboard

```
┌─────────────────────────────────────────────────────┐
│              SESSION STATISTICS                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐  ┌──────────────┐               │
│  │   DURATION   │  │   STATIONS   │               │
│  │              │  │              │               │
│  │   1h 45m     │  │      5       │               │
│  │              │  │              │               │
│  └──────────────┘  └──────────────┘               │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐               │
│  │  ELEVATION   │  │   DISTANCE   │               │
│  │              │  │              │               │
│  │   960m avg   │  │   11.0 km    │               │
│  │              │  │              │               │
│  └──────────────┘  └──────────────┘               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Progress Visualization (During Climb)

```
Stations Visited: 3 / 5 (60%)

Progress Bar:
┌─────────────────────────────────────────────────────┐
│████████████████████   ────────────────────        │
│●           ●           ●           ○           ○   │
│Station A   Station B   Station C   Station D   E   │
│                                                     │
│[●] = Visited    [○] = Not visited                  │
└─────────────────────────────────────────────────────┘

Live Timer: 1h 15m 30s (running)

Stations This Session:
├─ ✓ Station A (14:30)
├─ ✓ Station B (15:45)
├─ ✓ Station C (16:50)
├─ ○ Station D
└─ ○ Station E
```

## Color Coding

```
Status Colors:
├─ ONGOING   → Blue (#2196F3)
├─ COMPLETED → Green (#4CAF50)
├─ ABANDONED → Red (#F44336)
└─ DEFAULT   → Grey (#9E9E9E)

Component Colors:
├─ Primary Action   → Brand Blue
├─ Success         → Green
├─ Warning         → Orange
├─ Error           → Red
└─ Background      → Light Grey
```

## Responsive Design

```
Mobile (Portrait):
┌─────────────────┐
│                 │
│ Full width      │
│ Single column   │
│ Stacked cards   │
│                 │
└─────────────────┘

Tablet (Landscape):
┌──────────────────────────────────────┐
│         │         │         │         │
│ Grid    │ Layout  │ with    │ Cards   │
│         │         │         │         │
├─────────┴─────────┴─────────┴─────────┤
│                                      │
│ Multi-column timeline                │
│                                      │
└──────────────────────────────────────┘

Desktop (Wide):
┌──────────────────────────────────────────────────────┐
│                                                      │
│ Sidebar │         Main Content Area                 │
│         │  ┌────────────────────────────┐           │
│         │  │ Statistics Dashboard       │           │
│         │  │ ┌─────┐ ┌─────┐ ┌─────┐   │           │
│         │  │ │ Stat│ │Stat │ │Stat │   │           │
│         │  │ └─────┘ └─────┘ └─────┘   │           │
│         │  └────────────────────────────┘           │
│         │  ┌────────────────────────────┐           │
│         │  │ Timeline Visualization     │           │
│         │  │                            │           │
│         │  │                            │           │
│         │  └────────────────────────────┘           │
│         │                                           │
└──────────────────────────────────────────────────────┘
```

## Animation & Interactions

### Active Session Banner
```
[Slide up from bottom]
├─ Appears when session created
├─ Updates stats in real-time (no flash)
├─ Tap ripple effect on interaction
└─ Smooth dismissal when completed
```

### Station Timeline
```
[Fade in each station]
├─ Station marker appears
├─ Connection line draws
├─ Details fade in
└─ Smooth scroll animation
```

### Navigation Transitions
```
[Fade through]
├─ Dialog appears (scale + fade)
├─ Screen transitions (slide left/right)
├─ Back navigation (reverse animation)
└─ Smooth 200-300ms duration
```

## Dark Mode Support (Future)

```
Light Mode         Dark Mode
─────────────────────────────
White bg       →   Dark grey
Black text     →   White text
Light grey     →   Dark grey
Blue accent    →   Light blue
```

---

This visual guide shows the complete user journey through the Multi-Climb feature, from creating a new climb to viewing detailed statistics and history.
