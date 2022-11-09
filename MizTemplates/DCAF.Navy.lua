DCAF.Carrier:New("CVN-73") -- << -- name must be exactly the name of the carrier on map
                :SetTACANInactive(73, 'X', "C73")
                :SetICLSInactive(11)
                :WithArco1("DCAF Arco-1")
                :WithRescueHelicopter("DCAF CVN-73 Rescue")
                -- use RESCUEHELO:New (MOOSE) for more detailed control. Example:
                --:WithRescueHelicopter(RESCUEHELO:New(UNIT:FindByName("CVN-73-1"), ""DCAF CVN-73 Rescue"):SetTakeoffCold()) 
            -- add a second carrier ...
            -- :New("CVN-75"):SetTACAN(75, 'X', "C75"):SetICLS(15)
            -- :WithArco2("DCAF Arco-2")
                --    :WithRescueHelicopter("DCAF CVN-75 Rescue")
            -- add TARAWA ...
            -- :New("TARAWA"):SetTACAN(11, 'X', "LH1")
            -- build the player F10 navy menu system ...
            :AddF10PlayerMenus()