globals [ ticks tx-count current-server tx-per-user ]

breed [ servers server ]
servers-own [ overflow-count ]

breed [ threads thread ]
threads-own [ idle? server-id ttl tx-session ]

breed [ sessions session ]
sessions-own [ idle? ttl server-id tx-cnt ]

to setup
   ca
   set-default-shape servers "circle"
   set-default-shape threads "default"
   set-default-shape sessions "person"

   ; Create servers.
   create-custom-servers cluster-size [ 
      set color gray
      set size 3
      set overflow-count 0
   ]

   __layout-circle sort servers 10
   
   ; Create initial threads and sessions.
   repeat cluster-size [
      get-next-server
      repeat initial-threads [ create-thread ]
      repeat initial-users / count servers [ create-session ]
   ]
   
   calc-stats
end

to go
   no-display
   set tx-per-user tx-volume / (max-users / tx-volume)

   repeat tx-volume [
      get-next-server
      let tx-duration (random max-duration) + 1

      ; Check for enough threads; create more if needed.
      let ta-cnt (count threads with [server-id = current-server and not idle?])
      let t-cnt (count threads with [server-id = current-server])
      if ta-cnt / t-cnt > .9 [ overflow-threads ]

      ; Activate thread.
      let t one-of threads with [server-id = current-server and idle?] 
      ask t [ activate-thread tx-duration ]

      ; Find a session; create if needed.
      if not any? sessions with [server-id = current-server and tx-cnt < tx-per-user] [
         create-session
      ]
      
      ; Activate session.
      let s one-of sessions with [server-id = current-server and tx-cnt < tx-per-user] 
      ask s [
         if idle? [ activate-session ]
         set tx-cnt tx-cnt + 1
      ]
      
      ; Link thread to session.
      ask t [ set tx-session s ]

      set tx-count tx-count + 1
   ]

   ; Clean up threads.
   ask threads with [not idle?] [
      set ttl ttl - 1

      if ttl = 0 [
         ask tx-session [ 
            set tx-cnt tx-cnt - 1
            if tx-cnt = 0 [ deactivate-session ]
         ]
         deactivate-thread
      ]
   ]

   ; Clean up sessions.
   ask sessions with [idle?] [
      set ttl ttl - 1
      if ttl = 0 [ die ]
   ]

   calc-stats
   set ticks ticks + 1
   display
end

to get-next-server
   set current-server (current-server + 1) mod cluster-size
end

to create-thread
   create-custom-threads 1 [
      set server-id current-server
      deactivate-thread
   ]
   ;layout-threads
end

to activate-thread [ tx-dur ]
   set idle? false
   set color red
   set ttl tx-dur
   layout-threads
end

to deactivate-thread
   set idle? true
   set color green
   set ttl -1
   set tx-session 0
   layout-threads
end

to overflow-threads
   repeat 5 [ create-thread ]
   ask server current-server [
      set overflow-count overflow-count + 5
      set color orange
   ]
end

to layout-threads
   ;__layout-circle threads max-pxcor - 1
   __layout-circle sort-by [color-of ?1 < color-of ?2] threads max-pxcor - 1
end

to create-session
   create-custom-sessions 1 [
      set server-id current-server
      set size .9
      deactivate-session
   ]
   ;layout-sessions
end

to activate-session
   set idle? false
   set color red
   set ttl -1
   layout-sessions
end

to deactivate-session
   set idle? true
   set color green
   set ttl 1200
   layout-sessions
end

to layout-sessions
   ;__layout-circle sessions max-pxcor
   __layout-circle sort-by [color-of ?1 < color-of ?2] sessions max-pxcor
end

to calc-stats
   ask servers [
      let i who
      set label
         count sessions with [server-id = i] + ":" +
         count sessions with [server-id = i and not idle?] + "," +
         count sessions with [server-id = i and idle?] + "|" +
         count threads with [server-id = i] + ":" +
         count threads with [server-id = i and not idle?] + "," +
         count threads with [server-id = i and idle?] + "|" +
         overflow-count
   ]
end
@#$#@#$#@
GRAPHICS-WINDOW
207
10
785
609
35
35
8.0
1
10
1
1
1
0
1
1
1
-35
35
-35
35

CC-WINDOW
5
623
794
718
Command Center
0

BUTTON
7
329
70
362
NIL
setup
NIL
1
T
OBSERVER
T
NIL

BUTTON
72
329
135
362
NIL
go
T
1
T
OBSERVER
T
NIL

SLIDER
7
10
179
43
tx-volume
tx-volume
0
500
37
1
1
tx/sec

SLIDER
7
45
179
78
max-duration
max-duration
0
30
5
1
1
sec

MONITOR
90
224
179
273
ticks
ticks
0
1

MONITOR
7
224
88
273
NIL
tx-count
0
1

SLIDER
7
80
179
113
initial-threads
initial-threads
1
400
75
1
1
NIL

SLIDER
7
185
179
218
cluster-size
cluster-size
1
25
2
1
1
NIL

BUTTON
137
329
200
362
step
go
NIL
1
T
OBSERVER
T
NIL

SLIDER
7
115
179
148
initial-users
initial-users
0
2000
320
1
1
NIL

SLIDER
7
150
179
183
max-users
max-users
0
5000
1094
1
1
NIL

MONITOR
7
275
88
324
NIL
tx-per-user
3
1

@#$#@#$#@
WHAT IS IT?
-----------
This model is a simulation of sessions and transactions on WebLogic.


HOW IT WORKS
------------
The model starts with cluster-size servers and initial-users sessions and initial-threads on each server. For each iteration tx-volume transactions are simulated using the following algorithm:

* Select the next server (round robin).
* Calculate a random transaction duration between 1 and max-duration.
* If more than 90% of the threads are active, create threads-increase threads (overflow).
* Activate a thread that will live for the transaction duration.
* If no sessions have less than tx-per-user transactions, create a session.
* Add the transaction to a session.

After the transactions are run:

* Threads that have been active for their transaction durations are deactivated.
* Sessions that have no more transactions are deactivated.
* Sessions that have been idle for 1200 seconds are killed.

HOW TO USE IT
-------------
Set the initial conditions using the sliders. Press "go" to run the model continually. Press "step" to run one iteration.

World & View:

* Shapes: circles = servers, small triangles = threads, people = sessions
* Colors: red = active, green = idle, orange = thread overflow
* Server Labels: <sessions>:<active>,<idle>|<threads>:<active>,<idle>|<threads-added>

Sliders:

* tx-volume - transaction volume (rate)
* max-duration - maximum transaction duration
* initial-threads - initial threads to create on each server
* initial-users - initial users (sessions) to create on each server
* max-users - maximum users expected across all servers
* cluster-size - number of servers

Buttons:

* setup - Create servers, initial threads, and initial sessions.
* go - Run tx-volume transactions forever.
* step - Run tx-volume transactions for one iteration (tick).

Monitors:

* tx-count - number of transactions run
* ticks - simulated seconds
* tx-per-users - maximum number of transactions that will be run by a user (session)


CREDITS AND REFERENCES
----------------------
Model created by Thornton Rose (thornton@rosesquared.org)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
