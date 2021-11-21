with Ada.Real_Time;                            use Ada.Real_Time;
with Exceptions;                               use Exceptions;
with Real_Type;                                use Real_Type;
with Vectors_3D;                               use Vectors_3D;
with Vehicle_Interface;                        use Vehicle_Interface;
with Vehicle_Message_Type;                     use Vehicle_Message_Type;
with Swarm_Structures_Base;                    use Swarm_Structures_Base;
with Swarm_Configuration;                      use Swarm_Configuration;
with Swarm_Size;                               use Swarm_Size;
with Ada.Numerics.Long_Elementary_Functions;   use Ada.Numerics.Long_Elementary_Functions;

package body Vehicle_Task_Type is

   task body Vehicle_Task is

      -- unique Id of the vehicle
      Vehicle_No : Positive;
      -- initial destination, vehicles go to origin point at first
      Destination : Vector_3D := (others => 0.0);
      -- information of finding globes
      -- Globes_Found : Natural := 1;
      -- initialize the variables, so that go to (0, 0, 0) at first, and remain the same if not receiving a new globe place
      Globe : Energy_Globe :=
        (Position => (others => 0.0),
         Velocity => (others => 0.0));
      -- Message store the message just received.
      Message : Inter_Vehicle_Messages;
      -- Pre_Message actually stores the newest information of the globe
      -- will be initialized once Vehicle_No is given.
      Pre_Message : Inter_Vehicle_Messages;
      -- Radius stores the distance between globe and vehicle's destination -- the radius of sphere
      Radius : Real;
      -- X, Y, Z store the coordinate of vehicle's position if globe is origin of coordinates and radius is 1
      X_Coordinate, Y_Coordinate, Z_Coordinate : Real;
      -- Estimated_Time is the estimated time to catch the globe
      Estimated_Time : Real;
      -- Charge_Init stores the initial charge of the vehicle, which is considered to be full-charged
      -- so it is actually a constant variable, but should be assigned after the task begins
      Charge_Init : Vehicle_Charges;
      -- Throttle is the throttle of vehicles normally.
      Throttle : constant Throttle_T := 0.5;
      -- Default_Vehicle_Num is used to adjust the radius of the model
      -- in respect to Radius_Rate Pre_Message.Vehicle_Num to Default_Vehicle_Num
      Default_Vehicle_Num : constant Real := 64.0;
      -- Radius_Rate is the ratio of radius to Energy_Globe_Detection when it's Default_Vehicle_Num
      Radius_Rate : constant Real := 1.3;
      -- PI is namely pi, ratio of the circumference of a circle to its diameter
      PI : constant Real := 3.1415926536;
      -- Phi is the golden ratio, known as 0.618
      Phi : constant Real := (Sqrt (5.0) - 1.0) / 2.0;

      -- stage 3 definitions & initialization
      -- Valid_Globe is used to check if Globe is really a globe,
      -- because initially it's (others => 0) to let vehicles go to the origin point
      -- it's false only when globe is the initial (others => 0), which means globe is not valid
      Valid_Globe : Boolean := False;
      -- if the last time we found the globe till now is beyond Invalid_Time, then we think it's vanished
      Invalid_Time : constant Real := 2.0;
      -- Time_Init is when the task begins
      Time_Init : constant Time := Clock;

      -- stage 4 definitions & initialization
      -- vehicles tries to be in the destruction plan initially
      -- Now_Destruct shows if the vehicle need to destruct itself now
      Now_Destruct : Boolean :=  False;
      -- Will_Destruct shows if the vehicle want to be in the destruction plan
      Will_Destruct : Boolean := True;
      -- if the last we fulfill the destruction plan time till now is beyond Tolerant_Time, then the destruction plan should start
      Tolerant_Time : constant Duration := 5.0;

      -- other variables that would be used:
      -- Energy_Globe_Detection: the distance that vehicle can detect the globe and get charged, in Swarm/swarm_configuration.ads
      -- Target_No_of_Elements: the target number of vehicles for stage 4, in Vehicle_Interface/swarm_size.ads

   begin
      -- accept the unique id of the vehicle
      accept Identify (Set_Vehicle_No : Positive; Local_Task_Id : out Task_Id) do
         Vehicle_No     := Set_Vehicle_No;
         Local_Task_Id  := Current_Task;
      end Identify;
      -- store the initial charge of the vehicle which is thought to be full-charged
      Charge_Init := Current_Charge;
      -- initialize Pre_Message
      Pre_Message.Vehicle_Num := Vehicle_No;
      Pre_Message.Position := Globe.Position;
      Pre_Message.Velocity := Globe.Velocity;
      Pre_Message.Time_Of_Finding := Clock;

      -- stage 4 initialization
      Pre_Message.Number_Of_Volunteers := 1;
      Pre_Message.When_Decide := Clock;
      Pre_Message.Vehicles (1) := Vehicle_No;

      -- ensure all vehicles go to origin point at first
      Set_Destination (Destination);
      Set_Throttle (Throttle);

      -- repeat the following loop till the end of the task
      select

         Flight_Termination.Stop;

      then abort

         Outer_task_loop : loop

            Wait_For_Next_Physics_Update;

            -- if find the globe, update the information, then send the message

            if Energy_Globes_Around'Length /= 0
            then
               -- by default, only find 1 globe, because find 2 is of very low possibility
               Globe := Energy_Globes_Around (1);
               Pre_Message.Position := Globe.Position;
               Pre_Message.Velocity := Globe.Velocity;
               Pre_Message.Time_Of_Finding := Clock;
               -- find 3 globes at a time is almost impossible, so only consider finding 1 and 2 at a time
               if Energy_Globes_Around'Length > 1
               then
                  if abs (Position - Energy_Globes_Around (2).Position) < abs (Position - Pre_Message.Position)
                  then
                     Globe := Energy_Globes_Around (2);
                     Pre_Message.Position := Globe.Position;
                     Pre_Message.Velocity := Globe.Velocity;
                  end if;
               end if;
               Send (Message => Pre_Message);

            else
               Send (Message => Pre_Message);
            end if;

            -- receive the message
            Receive (Message => Message);

            -- stage 4 part starts here

            -- update the destruction plan if it's longer, or as long but earlier made
            if Message.Number_Of_Volunteers > Pre_Message.Number_Of_Volunteers
            then
               Pre_Message.Number_Of_Volunteers := Message.Number_Of_Volunteers;
               Pre_Message.When_Decide := Message.When_Decide;
               Pre_Message.Vehicles := Message.Vehicles;
            elsif Message.Number_Of_Volunteers = Pre_Message.Number_Of_Volunteers
                   and then Message.When_Decide < Pre_Message.When_Decide
            then
               Pre_Message.Number_Of_Volunteers := Message.Number_Of_Volunteers;
               Pre_Message.When_Decide := Message.When_Decide;
               Pre_Message.Vehicles := Message.Vehicles;
            end if;

            -- if Will_Destruct, check if the vehicle is in the destruction plan after the plan update
            -- elsif plan is not full, try to be in the plan
            if Will_Destruct
            then
               Will_Destruct := False;
               for i in 1 .. Pre_Message.Number_Of_Volunteers loop
                  if Pre_Message.Vehicles (i) = Vehicle_No then
                     Will_Destruct := True;
                  end if;
               end loop;
            elsif Pre_Message.Number_Of_Volunteers < Pre_Message.Vehicle_Num - Target_No_of_Elements
            then
               Pre_Message.When_Decide := Clock;
               Will_Destruct := True;
               Pre_Message.Number_Of_Volunteers := Pre_Message.Number_Of_Volunteers + 1;
               Pre_Message.Vehicles (Pre_Message.Number_Of_Volunteers) :=  Vehicle_No;
            end if;
            -- stage 4 part ends here

            -- update Pre_Message.Vehicle_Num
            if Message.Vehicle_Num > Pre_Message.Vehicle_Num
            then
               Pre_Message.Vehicle_Num := Message.Vehicle_Num;
            end if;

            -- update globe if message.globe is valid and closer, or valid and pre_is_not_valid
            if Real (To_Duration (Clock - Message.Time_Of_Finding)) < Invalid_Time
            then
               if abs (Position - Message.Position) < abs (Position - Pre_Message.Position)
               then
                  Globe.Position := Message.Position;
                  Globe.Velocity := Message.Velocity;
                  Pre_Message.Position := Globe.Position;
                  Pre_Message.Velocity := Globe.Velocity;
                  Pre_Message.Time_Of_Finding := Message.Time_Of_Finding;
                  -- since globe is no longer the origin point, update Valid_Globe
                  Valid_Globe := True;
               elsif Real (To_Duration (Clock - Pre_Message.Time_Of_Finding)) >= Invalid_Time
                 or else Valid_Globe = False
               then
                  Globe.Position := Message.Position;
                  Globe.Velocity := Message.Velocity;
                  Pre_Message.Position := Globe.Position;
                  Pre_Message.Velocity := Globe.Velocity;
                  Pre_Message.Time_Of_Finding := Message.Time_Of_Finding;
                  Valid_Globe := True;
               end if;
            end if;

            -- update globe position regarding time-passing
            Globe.Position := Pre_Message.Position + Pre_Message.Velocity * Real (To_Duration (Clock - Pre_Message.Time_Of_Finding));
            if Real (To_Duration (Clock - Pre_Message.Time_Of_Finding)) >= Invalid_Time
            then
               Globe.Position := (others => 0.0);
               Pre_Message.Position := Globe.Position;
               Pre_Message.Velocity := (others => 0.0);
               Pre_Message.Time_Of_Finding := Time_Init;
            end if;

            -- part for set destination

            -- stage 4 part starts here
            -- see if the vehicle is in the destruction plan
            for i in 1 .. Pre_Message.Number_Of_Volunteers loop
               if Pre_Message.Vehicles (i) = Vehicle_No then
                  Now_Destruct := True;
               end if;
            end loop;
            -- if the vehicle is now destructing itself, let the default swarming behavior take over
            if Pre_Message.Number_Of_Volunteers >= Pre_Message.Vehicle_Num - Target_No_of_Elements
                and then Now_Destruct and then To_Duration (Clock - Pre_Message.When_Decide) > Tolerant_Time
            then
               null;
            else
               -- the vehicle is not going to destruction itself now
               Now_Destruct := False;
            -- stage 4 part ends here

               -- update radius regarding Energy_Globe_Detection and number of vehicles
               -- Comms_Range(within which distance vehicles can communicate with each other, in Swarm/swarm_configuration.ads) is 0.2
               -- while Energy_Globe_Detection is 0.07
               Radius := Radius_Rate * Energy_Globe_Detection * Sqrt (Real (Pre_Message.Vehicle_Num) / Default_Vehicle_Num);
               -- update radius regarding charge changing
               Radius := Radius * Sqrt (Real (Current_Charge / Charge_Init));
               -- cauculate the Estimated_Time regaring to Velocity and Acceleration
               -- stage 4: and add the Invalid_Time
               Estimated_Time := (Sqrt ((Real (abs (Velocity)) ** 2) + 2.0 * abs (Acceleration) * Radius)
                                  - abs (Velocity)) / abs (Acceleration) + Invalid_Time;

               -- if vehicle needs to be charged, rush to the globe as fast as it can, or else find its position around the globe
               if Real (Current_Charge) - Estimated_Time * Current_Discharge_Per_Sec < Real (0.1 * Charge_Init)
               then
                  Destination := Globe.Position;
                  Set_Destination (Destination);
                  Set_Throttle (Throttle * 2.0);
               else
                  -- the aim is to evenly distribute the vehicles around the globe
                  -- see the algorithm at:
                  -- https://stackoverflow.com/questions/9600801/evenly-distributing-n-points-on-a-sphere/26127012#26127012
                  Z_Coordinate := (2.0 * Real (Vehicle_No) - 1.0) / Real (Pre_Message.Vehicle_Num) - 1.0;
                  X_Coordinate := Sqrt (1.0 - (Z_Coordinate ** 2)) * Cos (2.0 * PI * Real (Vehicle_No) * Phi);
                  Y_Coordinate := Sqrt (1.0 - (Z_Coordinate ** 2)) * Sin (2.0 * PI * Real (Vehicle_No) * Phi);
                  Destination (x) := Globe.Position (x) + Radius * X_Coordinate;
                  Destination (y) := Globe.Position (y) + Radius * Y_Coordinate;
                  Destination (z) := Globe.Position (z) + Radius * Z_Coordinate;
                  Set_Destination (Destination);
                  Set_Throttle (Throttle);
               end if;
            end if;

         end loop Outer_task_loop;

      end select;

   exception
      when E : others => Show_Exception (E);

   end Vehicle_Task;

end Vehicle_Task_Type;
