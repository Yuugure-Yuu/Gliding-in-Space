with Ada.Real_Time;         use Ada.Real_Time;
with Swarm_Size;            use Swarm_Size;
with Vectors_3D;            use Vectors_3D;

package Vehicle_Message_Type is

   type Vehicle_Type is array (Positive range <>) of Positive;

   type Inter_Vehicle_Messages is

      record
         -- Number of Vehicles
         Vehicle_Num : Positive;
         -- informations of the finding globe
         Position : Vector_3D;
         Velocity : Vector_3D;
         -- timestamp of finding the energy globe
         Time_Of_Finding : Time;

         -- stage 4 definitions
         -- the destruction plan list, stores id of vehicles
         Vehicles : Vehicle_Type (1 .. Target_No_of_Elements);
         -- the number of vehicles already scheduled for destruction
         Number_Of_Volunteers : Natural;
         -- the time when the last decision made for the destruction plan
         When_Decide : Time;

      end record;

end Vehicle_Message_Type;
