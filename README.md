# Gliding-in-Space

## Overview

Coordinating behaviours and resources in a concurrent and distributed way is at the heart of this course. The setting for this assignment is a swarm of physical vehicles in 3D space.

We have provided a code framework that models and simulates a swarm of vehicles that follow simple default behaviours to keep them in motion together and avoid collisions. All vehicles have a local *charge* to keep them *alive*. For physical reasons yet unknown, the vehicles replenish their charge to full by passing *energy globes* in close proximity. Vehicles that run out of charge mysteriously disappear. Vehicles constantly consume energy to keep their onboard systems running and consume substantially more energy when accelerating or decelerating.

![Swarming robots in space](https://cs.anu.edu.au/courses/comp2310/assignments/Swarm%20wuseling.png)

## Sensors, Actuators & Communication

Each vehicle is operated by a dedicated task that has access to local sensors, communication interfaces and actuators.

The sensors include position, velocity and acceleration, as well as current charge. If the vehicle is close enough to one or more energy globes to utilize them, the sensors also display the position and current velocity of all close energy globes.

The actuator system consists of setting an absolute destination position and throttle value. The underlying cruise control system automatically handles the steering and acceleration. Once the destination point has been reached, the throttle automatically switches back to idle, which means that default swarming behaviour takes over. The vehicles do not slow down when approaching the destination and rather pass through the destination point. This helps to keep the controls fluent and the vehicles in motion. Collision avoidance reflexes are always active and prevent vehicles from crashing into each other. Note that a destination might become unreachable if multiple vehicles are bound for the same destination.

The vehicles are also equipped with a message-passing system, which can broadcast a message that will be received by all vehicles in close proximity. This is asynchronous, and there is no feedback on whether any message has been received by any vehicle – unless another vehicle actively sends a message in response.

Finally, there is also a function that allows direct access to the underlying, secret clock of the world. `Wait_For_Next_Physics_Update` will put the task to sleep until anything actually happened (which includes communication). This relieves the vehicles from busy-waiting for the world to change.

All the above controls are found in `Sources/Vehicle_Interface/vehicle_interface.ads`.

## Visualization

The provided graphical animation of the swarm offers third-person views as well as the view from one of the vehicles while it is passing through the swarm. The communication range can be visualized by drawing connecting lines between all vehicles which are currently in range. The colours represent their charging state as well as the control state. Turquoise vehicles are currently following their swarming instincts are not explicitly controlled by the associated task. The colour saturation reflects the level of charge. Once vehicles go into manual control (throttle and destination are set), they turn to a more red colour schema. The energy globe(s) are dark ruby coloured spheres.

## Design Constraints

The solution that you produce should be deployable on actual vehicles. Hence only the provided interfaces to physical sensors and forms of communications are allowed. “Looking underneath the hood”, for example, using global information about times or positions, is useful to help understand the problem. Bypassing the provided interfaces and using information from inside the simulator is obviously counterproductive for any future physical deployment and hence not allowed. Nevertheless, the first stage of the assignment will allow you to introduce additional means of communication which cannot necessarily be physically implemented.

## Timing Constraints

All calculations inside the vehicle tasks have an implicit deadline given by the update from the underlying physics engine. This is not seen as a hard deadline by the local tasks, yet if many tasks overrun the deadline, it will slow down the simulator. Simulated time is not affected by this – only the update time intervals will become larger.

## Design Goals

The overall design goal is to keep as many vehicles alive as possible for as long as possible. As energy globes can only be discovered locally, both communication and coordination between vehicles are required, as all swarm members heading for the same destination at the same time will result in many of them failing to reach it.

The task can be solved in four stages:

1. Allowing a central coordinator.
2. Fully distributed.
3. Multiple energy globes.
4. Find harmony.

Stage 1 still allows for a central coordinator to be introduced, and all tasks are allowed to communicate with this entity (or multiple thereof). The implementation of those central instances can employ shared memory based as well as message based forms of communication. Some are obviously questionable to impossible in a physical deployment of your system, yet this stage might help you to develop ideas that can then be considered for the second stage.

Stage 2 does not allow for a central coordinator, and all planning and scheduling now needs to be done on the individual vehicles only using local communication. This is hard. If you are confident that you are up for stage 2 straightaway, you do not need to implement stage 1.

Stage 3 requires further coordination between vehicles as multiple energy globes are to be considered. Assume that you do not know how many globes are in existence, yet utilize the additional redundancy which is detected at runtime to enhance the overall robustness of your swarm charging method. To test this, you will need to go to the package `Swarm_Configuration` and change `Configuration` to `Random_Globes_In_Orbits`. Globes can appear and vanish at random, yet there will be a minimum of 2 globes around at all times.

Stage 4 requires all of the above, plus that the swarm shrinks itself to a specific size. The target size is a constant (`Target_No_of_Elements`) that is known to all vehicles, yet they do not know (initially) how many vehicles exist or whether a particular vehicle is scheduled for destruction. This stage will require a fully distributed method to share information and agree on action (in this case, to purposefully let certain vehicles run out of energy and vanish).

### Survival

The first priority is to get over the initial phase without anybody dying. This could be impossible if no vehicle finds an energy globe before the initial charges run out. Don’t worry about this case – this is just nature, and you cannot do anything about it.

Once one or more globes are found, you need to ensure that the information is spread effectively.

Now comes the real challenge of how to coordinate the vehicles. Find ways to coordinate their paths. This might lead to different strategies in stage 1 and stage 2.