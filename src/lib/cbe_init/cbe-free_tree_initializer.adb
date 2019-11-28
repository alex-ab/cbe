--
--  Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
--
--  This file is part of the Consistent Block Encrypter project, which is
--  distributed under the terms of the GNU Affero General Public License
--  version 3.
--

pragma Ada_2012;

with SHA256_4K;
with CBE.Debug;

pragma Unreferenced (CBE.Debug);

package body CBE.Free_Tree_Initializer
with SPARK_Mode
is
   procedure CBE_Hash_From_SHA256_4K_Hash (
      CBE_Hash : out Hash_Type;
      SHA_Hash :     SHA256_4K.Hash_Type);

   procedure SHA256_4K_Data_From_CBE_Data (
      SHA_Data : out SHA256_4K.Data_Type;
      CBE_Data :     Block_Data_Type);

   procedure CBE_Hash_From_SHA256_4K_Hash (
      CBE_Hash : out Hash_Type;
      SHA_Hash :     SHA256_4K.Hash_Type)
   is
      SHA_Idx : SHA256_4K.Hash_Index_Type := SHA256_4K.Hash_Index_Type'First;
   begin
      for CBE_Idx in CBE_Hash'Range loop
         CBE_Hash (CBE_Idx) := Byte_Type (SHA_Hash (SHA_Idx));
         if CBE_Idx < CBE_Hash'Last then
            SHA_Idx := SHA_Idx + 1;
         end if;
      end loop;
   end CBE_Hash_From_SHA256_4K_Hash;

   procedure SHA256_4K_Data_From_CBE_Data (
      SHA_Data : out SHA256_4K.Data_Type;
      CBE_Data :     Block_Data_Type)
   is
      CBE_Idx : Block_Data_Index_Type := Block_Data_Index_Type'First;
   begin
      for SHA_Idx in SHA_Data'Range loop
         SHA_Data (SHA_Idx) := SHA256_4K.Byte (CBE_Data (CBE_Idx));
         if SHA_Idx < SHA_Data'Last then
            CBE_Idx := CBE_Idx + 1;
         end if;
      end loop;
   end SHA256_4K_Data_From_CBE_Data;

   function Hash_Of_Type_1_Node_Block (Block : Type_1_Node_Block_Type)
   return Hash_Type
   is
   begin
      Declare_Hash_Data :
      declare
         SHA_Hash : SHA256_4K.Hash_Type;
         SHA_Data : SHA256_4K.Data_Type;
         CBE_Data : Block_Data_Type;
         CBE_Hash : Hash_Type;
      begin
         Block_Data_From_Type_1_Node_Block (CBE_Data, Block);
         SHA256_4K_Data_From_CBE_Data (SHA_Data, CBE_Data);
         SHA256_4K.Hash (SHA_Data, SHA_Hash);
         CBE_Hash_From_SHA256_4K_Hash (CBE_Hash, SHA_Hash);
         return CBE_Hash;
      end Declare_Hash_Data;
   end Hash_Of_Type_1_Node_Block;

   function Hash_Of_Type_2_Node_Block (Block : Type_2_Node_Block_Type)
   return Hash_Type
   is
   begin
      Declare_Hash_Data :
      declare
         SHA_Hash : SHA256_4K.Hash_Type;
         SHA_Data : SHA256_4K.Data_Type;
         CBE_Data : Block_Data_Type;
         CBE_Hash : Hash_Type;
      begin
         Block_Data_From_Type_2_Node_Block (CBE_Data, Block);
         SHA256_4K_Data_From_CBE_Data (SHA_Data, CBE_Data);
         SHA256_4K.Hash (SHA_Data, SHA_Hash);
         CBE_Hash_From_SHA256_4K_Hash (CBE_Hash, SHA_Hash);
         return CBE_Hash;
      end Declare_Hash_Data;
   end Hash_Of_Type_2_Node_Block;

   procedure Initialize_Object (Obj : out Object_Type)
   is
   begin
      Obj.Max_Lvl_Idx      := Tree_Level_Index_Type'First;
      Obj.Max_Child_Idx    := Tree_Child_Index_Type'First;
      Obj.Nr_Of_Leafs      := Tree_Number_Of_Leafs_Type'First;
      Obj.Gen_Prim_Dropped := False;
      Obj.Gen_Prim         := Primitive.Invalid_Object;
      Obj.Subm_Prim        := Primitive.Invalid_Object;
      Obj.Lvl_To_Write     := Tree_Level_Index_Type'First;
      Obj.Execute_Progress := False;
      Obj.Root_State       := Done;
      Obj.Root             := (0, 0, (others => 0));

      For_T1_Lvls :
      for Idx in Type_1_Level_Index_Type loop
         Obj.T1_Lvls (Idx).Children_State := (others => Done);
         Obj.T1_Lvls (Idx).Children       := (
            others => (0, 0, (others => 0)));
      end loop For_T1_Lvls;

      Obj.T2_Lvl.Children_State := (others => Done);
      Obj.T2_Lvl.Children       := (others => (0, 0, 0, 0, 0, False));

   end Initialize_Object;

   function Primitive_Acceptable (Obj : Object_Type)
   return Boolean
   is (not Primitive.Valid (Obj.Subm_Prim));

   procedure Submit_Primitive (
      Obj           : in out Object_Type;
      Prim          :        Primitive.Object_Type;
      Max_Lvl_Idx   :        Tree_Level_Index_Type;
      Max_Child_Idx :        Tree_Child_Index_Type;
      Nr_Of_Leafs   :        Tree_Number_Of_Leafs_Type)
   is
   begin
      if Primitive.Valid (Obj.Subm_Prim) then
         raise Program_Error;
      end if;
      Obj.Subm_Prim := Prim;
      Obj.Max_Lvl_Idx := Max_Lvl_Idx;
      Obj.Max_Child_Idx := Max_Child_Idx;
      Obj.Nr_Of_Leafs := Nr_Of_Leafs;
      Obj.Root_State := Init_Block;
   end Submit_Primitive;

   function Peek_Completed_Primitive (Obj : Object_Type)
   return Primitive.Object_Type
   is
   begin
      if not Primitive.Valid (Obj.Subm_Prim) or else
         Obj.Root_State /= Done
      then
         return Primitive.Invalid_Object;
      end if;
      return Obj.Subm_Prim;
   end Peek_Completed_Primitive;

   function Peek_Completed_Root (
      Obj  : Object_Type;
      Prim : Primitive.Object_Type)
   return Type_1_Node_Type
   is
   begin
      if not Primitive.Valid (Obj.Subm_Prim) or else
         not Primitive.Equal (Obj.Subm_Prim, Prim) or else
         Obj.Root_State /= Done
      then
         raise Program_Error;
      end if;
      return Obj.Root;

   end Peek_Completed_Root;

   procedure Drop_Completed_Primitive (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type)
   is
   begin
      if not Primitive.Valid (Obj.Subm_Prim) or else
         not Primitive.Equal (Obj.Subm_Prim, Prim) or else
         Obj.Root_State /= Done
      then
         raise Program_Error;
      end if;
      Initialize_Object (Obj);

   end Drop_Completed_Primitive;

   procedure Execute_Leaf_Child (
      Nr_Of_Leafs  : in out Tree_Number_Of_Leafs_Type;
      Progress     : in out Boolean;
      Prim         : in out Primitive.Object_Type;
      Prim_Dropped : in out Boolean;
      Child        : in out Type_2_Node_Type;
      Child_State  : in out Child_State_Type;
      Child_Idx    :        Type_2_Node_Block_Index_Type)
   is
   begin
      if Child_State = Init_Block then

         Child_State := Init_Node;
         Progress    := True;

      elsif Child_State = Init_Node then

         if Nr_Of_Leafs = 0 then

            Child       := (0, 0, 0, 0, 0, False);
            Child_State := Done;
            Progress    := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node 1 " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", assign pba 0, leaf unused"));

         else

            if not Primitive.Valid (Prim) then

               Prim_Dropped := False;
               Prim         :=
                  Primitive.Valid_Object_No_Pool_Idx (
                     Read, False, Primitive.Tag_FT_Init_Blk_Alloc, 0, 0);

               Progress := True;

            elsif not Primitive.Has_Tag_FT_Init_Blk_Alloc (Prim) then

               raise Program_Error;

            elsif not Primitive.Success (Prim) then

               null;

            else

               Child := (
                  Physical_Block_Address_Type (
                     Primitive.Block_Number (Prim)),
                  0, 0, 0, 0, False);

               Prim_Dropped := False;
               Prim         := Primitive.Invalid_Object;
               Child_State  := Done;
               Nr_Of_Leafs  := Nr_Of_Leafs - 1;
               Progress     := True;

               pragma Debug (
                  Debug.Print_String (
                     "[ft_init] node 1 " &
                     Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                     ", assign pba " &
                     Debug.To_String (Debug.Uint64_Type (Child.PBA)) &
                     ", leafs left " &
                     Debug.To_String (Debug.Uint64_Type (Nr_Of_Leafs))));
            end if;
         end if;
      end if;

      pragma Unreferenced (Child_Idx);

   end Execute_Leaf_Child;

   procedure Execute_Inner_T1_Child (
      Nr_Of_Leafs  :        Tree_Number_Of_Leafs_Type;
      Progress     : in out Boolean;
      Prim         : in out Primitive.Object_Type;
      Prim_Dropped : in out Boolean;
      Lvl_To_Write : in out Tree_Level_Index_Type;
      Child        : in out Type_1_Node_Type;
      Child_Lvl    : in out Type_1_Level_Type;
      Child_State  : in out Child_State_Type;
      Lvl_Idx      :        Type_1_Level_Index_Type;
      Child_Idx    :        Type_1_Node_Block_Index_Type)
   is
   begin

      if Child_State = Init_Block then

         if Nr_Of_Leafs = 0 then

            Child       := (0, 0, (others => 0));
            Child_State := Done;
            Progress    := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                  " " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", assign pba 0, inner node unused"));

         else

            Child_Lvl.Children       := (others => (0, 0, (others => 0)));
            Child_Lvl.Children_State := (others => Init_Block);
            Child_State              := Init_Node;
            Progress                 := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                  " " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", reset lvl " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx - 1))));

         end if;

      elsif Child_State = Init_Node then

         if not Primitive.Valid (Prim) then

            Prim_Dropped := False;
            Prim         :=
               Primitive.Valid_Object_No_Pool_Idx (
                  Read, False, Primitive.Tag_FT_Init_Blk_Alloc, 0, 0);

            Progress := True;

         elsif not Primitive.Has_Tag_FT_Init_Blk_Alloc (Prim) then

            raise Program_Error;

         elsif not Primitive.Success (Prim) then

            null;

         else
            Child := (
               Physical_Block_Address_Type (
                  Primitive.Block_Number (Prim)),
               0, Hash_Of_Type_1_Node_Block (Child_Lvl.Children));

            Prim_Dropped := False;
            Prim         := Primitive.Invalid_Object;
            Child_State  := Write_Block;
            Progress     := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                  " " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", assign pba " &
                  Debug.To_String (Debug.Uint64_Type (Child.PBA))));

         end if;

      elsif Child_State = Write_Block then

         if not Primitive.Valid (Prim) then

            Prim_Dropped := False;
            Prim         :=
               Primitive.Valid_Object_No_Pool_Idx (
                  Write, False, Primitive.Tag_FT_Init_Blk_IO,
                  Block_Number_Type (Child.PBA), 0);

            Lvl_To_Write := Lvl_Idx - 1;
            Progress := True;

         elsif not Primitive.Has_Tag_FT_Init_Blk_IO (Prim) or else
               Primitive.Block_Number (Prim) /= Block_Number_Type (Child.PBA)
         then

            raise Program_Error;

         elsif not Primitive.Success (Prim) then

            null;

         else

            Prim_Dropped := False;
            Prim         := Primitive.Invalid_Object;
            Child_State  := Done;
            Progress     := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                  " " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", write pba " &
                  Debug.To_String (Debug.Uint64_Type (Child.PBA)) &
                  ", lvl " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx - 1))));

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] ------------------------------------------"));

         end if;
      end if;

      pragma Unreferenced (Child_Idx);

   end Execute_Inner_T1_Child;

   procedure Execute_Inner_T2_Child (
      Nr_Of_Leafs  :        Tree_Number_Of_Leafs_Type;
      Progress     : in out Boolean;
      Prim         : in out Primitive.Object_Type;
      Prim_Dropped : in out Boolean;
      Lvl_To_Write : in out Tree_Level_Index_Type;
      Child        : in out Type_1_Node_Type;
      Child_Lvl    : in out Type_2_Level_Type;
      Child_State  : in out Child_State_Type;
      Lvl_Idx      :        Type_1_Level_Index_Type;
      Child_Idx    :        Type_1_Node_Block_Index_Type)
   is
   begin

      if Child_State = Init_Block then

         if Nr_Of_Leafs = 0 then

            Child       := (0, 0, (others => 0));
            Child_State := Done;
            Progress    := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                  " " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", assign pba 0, inner node unused"));

         else

            Child_Lvl.Children       := (others => (0, 0, 0, 0, 0, False));
            Child_Lvl.Children_State := (others => Init_Block);
            Child_State              := Init_Node;
            Progress                 := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                  " " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", reset lvl " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx - 1))));

         end if;

      elsif Child_State = Init_Node then

         if not Primitive.Valid (Prim) then

            Prim_Dropped := False;
            Prim         :=
               Primitive.Valid_Object_No_Pool_Idx (
                  Read, False, Primitive.Tag_FT_Init_Blk_Alloc, 0, 0);

            Progress := True;

         elsif not Primitive.Has_Tag_FT_Init_Blk_Alloc (Prim) then

            raise Program_Error;

         elsif not Primitive.Success (Prim) then

            null;

         else
            Child := (
               Physical_Block_Address_Type (
                  Primitive.Block_Number (Prim)),
               0, Hash_Of_Type_2_Node_Block (Child_Lvl.Children));

            Prim_Dropped := False;
            Prim         := Primitive.Invalid_Object;
            Child_State  := Write_Block;
            Progress     := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                  " " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", assign pba " &
                  Debug.To_String (Debug.Uint64_Type (Child.PBA))));

         end if;

      elsif Child_State = Write_Block then

         if not Primitive.Valid (Prim) then

            Prim_Dropped := False;
            Prim         :=
               Primitive.Valid_Object_No_Pool_Idx (
                  Write, False, Primitive.Tag_FT_Init_Blk_IO,
                  Block_Number_Type (Child.PBA), 0);

            Lvl_To_Write := Lvl_Idx - 1;
            Progress := True;

         elsif not Primitive.Has_Tag_FT_Init_Blk_IO (Prim) or else
               Primitive.Block_Number (Prim) /= Block_Number_Type (Child.PBA)
         then

            raise Program_Error;

         elsif not Primitive.Success (Prim) then

            null;

         else

            Prim_Dropped := False;
            Prim         := Primitive.Invalid_Object;
            Child_State  := Done;
            Progress     := True;

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] node " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx)) &
                  " " &
                  Debug.To_String (Debug.Uint64_Type (Child_Idx)) &
                  ", write pba " &
                  Debug.To_String (Debug.Uint64_Type (Child.PBA)) &
                  ", lvl " &
                  Debug.To_String (Debug.Uint64_Type (Lvl_Idx - 1))));

            pragma Debug (
               Debug.Print_String (
                  "[ft_init] ------------------------------------------"));

         end if;
      end if;

      pragma Unreferenced (Child_Idx);

   end Execute_Inner_T2_Child;

   procedure Execute (Obj : in out Object_Type)
   is
   begin
      Obj.Execute_Progress := False;

      if not Primitive.Valid (Obj.Subm_Prim) then
         return;
      end if;

      For_T2_Lvl_Children :
      for Child_Idx in
         Type_2_Node_Block_Index_Type'First .. Max_T2_Child_Idx (Obj)
      loop

         if Obj.T2_Lvl.Children_State (Child_Idx) /= Done then

            Execute_Leaf_Child (
               Obj.Nr_Of_Leafs,
               Obj.Execute_Progress,
               Obj.Gen_Prim,
               Obj.Gen_Prim_Dropped,
               Obj.T2_Lvl.Children (Child_Idx),
               Obj.T2_Lvl.Children_State (Child_Idx),
               Child_Idx);
            return;

         end if;

      end loop For_T2_Lvl_Children;

      For_T1_Lvls :
      for Lvl_Idx in Type_1_Level_Index_Type'First .. Max_T1_Lvl_Idx (Obj)
      loop

         For_T1_Lvl_Children :
         for Child_Idx in
            Type_1_Node_Block_Index_Type'First .. Max_T1_Child_Idx (Obj)
         loop

            if Obj.T1_Lvls (Lvl_Idx).Children_State (Child_Idx) /= Done then

               if Lvl_Idx = Type_1_Level_Index_Type'First then
                  Execute_Inner_T2_Child (
                     Obj.Nr_Of_Leafs,
                     Obj.Execute_Progress,
                     Obj.Gen_Prim,
                     Obj.Gen_Prim_Dropped,
                     Obj.Lvl_To_Write,
                     Obj.T1_Lvls (Lvl_Idx).Children (Child_Idx),
                     Obj.T2_Lvl,
                     Obj.T1_Lvls (Lvl_Idx).Children_State (Child_Idx),
                     Lvl_Idx,
                     Child_Idx);
               else
                  Execute_Inner_T1_Child (
                     Obj.Nr_Of_Leafs,
                     Obj.Execute_Progress,
                     Obj.Gen_Prim,
                     Obj.Gen_Prim_Dropped,
                     Obj.Lvl_To_Write,
                     Obj.T1_Lvls (Lvl_Idx).Children (Child_Idx),
                     Obj.T1_Lvls (Lvl_Idx - 1),
                     Obj.T1_Lvls (Lvl_Idx).Children_State (Child_Idx),
                     Lvl_Idx,
                     Child_Idx);
               end if;
               return;

            end if;

         end loop For_T1_Lvl_Children;

      end loop For_T1_Lvls;

      if Obj.Root_State /= Done then
         Execute_Inner_T1_Child (
            Obj.Nr_Of_Leafs,
            Obj.Execute_Progress,
            Obj.Gen_Prim,
            Obj.Gen_Prim_Dropped,
            Obj.Lvl_To_Write,
            Obj.Root,
            Obj.T1_Lvls (Max_T1_Lvl_Idx (Obj)),
            Obj.Root_State,
            Obj.Max_Lvl_Idx + 1,
            Type_1_Node_Block_Index_Type'First);
         return;
      end if;

      if Obj.Nr_Of_Leafs = 0 then
         Primitive.Success (Obj.Subm_Prim, True);
      end if;

   end Execute;

   function Execute_Progress (Obj : Object_Type)
   return Boolean
   is (Obj.Execute_Progress);

   function Peek_Generated_Primitive (Obj : Object_Type)
   return Primitive.Object_Type
   is (
      if Obj.Gen_Prim_Dropped then
         Primitive.Invalid_Object
      else
         Obj.Gen_Prim);

   function Peek_Generated_Data (
      Obj  : Object_Type;
      Prim : Primitive.Object_Type)
   return Block_Data_Type
   is
      Data : Block_Data_Type;
   begin
      if not Primitive.Has_Tag_FT_Init_Blk_IO (Prim) or else
         not Primitive.Equal (Prim, Obj.Gen_Prim) or else
         Obj.Gen_Prim_Dropped
      then
         raise Program_Error;
      end if;

      if Obj.Lvl_To_Write =
         Tree_Level_Index_Type (Type_1_Level_Index_Type'First) - 1
      then
         Block_Data_From_Type_2_Node_Block (
            Data, Obj.T2_Lvl.Children);
      else
         Block_Data_From_Type_1_Node_Block (
            Data, Obj.T1_Lvls (Obj.Lvl_To_Write).Children);
      end if;
      return Data;
   end Peek_Generated_Data;

   procedure Drop_Generated_Primitive (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type)
   is
   begin
      if not Primitive.Equal (Prim, Obj.Gen_Prim) or else
         Obj.Gen_Prim_Dropped
      then
         raise Program_Error;
      end if;
      Obj.Gen_Prim_Dropped := True;
   end Drop_Generated_Primitive;

   procedure Mark_Generated_Primitive_Complete (
      Obj  : in out Object_Type;
      Prim :        Primitive.Object_Type)
   is
   begin
      if Primitive.Valid (Obj.Gen_Prim) and then
         Obj.Gen_Prim_Dropped and then
         ((Primitive.Has_Tag_FT_Init_Blk_Alloc (Obj.Gen_Prim) and then
           Primitive.Has_Tag_FT_Init_Blk_Alloc (Prim)) or else
          (Primitive.Has_Tag_FT_Init_Blk_IO (Obj.Gen_Prim) and then
           Primitive.Has_Tag_FT_Init_Blk_IO (Prim) and then
           Primitive.Block_Number (Obj.Gen_Prim) =
              Primitive.Block_Number (Prim)))
      then
         Obj.Gen_Prim := Prim;
      end if;
   end Mark_Generated_Primitive_Complete;

end CBE.Free_Tree_Initializer;
