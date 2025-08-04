local A={AutoMilestones=true}
getgenv().Config=A

local B=game:GetService("\82\101\112\108\105\99\97\116\101\100\83\116\111\114\97\103\101")
local C=game:GetService("\80\108\97\121\101\114\115")
local D=C.LocalPlayer
local E=B:WaitForChild("\83\104\97\114\101\100"):WaitForChild("\70\114\97\109\101\119\111\114\107"):WaitForChild("\78\101\116\119\111\114\107"):WaitForChild("\82\101\109\111\116\101"):WaitForChild("\82\101\109\111\116\101\69\118\101\110\116")
local F=require(B.Client.Framework.Services.LocalData)
local G=require(B.Shared.Data.Milestones)

local function H()
    pcall(function()
        local I=D:WaitForChild("\80\108\97\121\101\114\71\117\105")
        local J=I:WaitForChild("\83\99\114\101\101\110\71\117\105")
        if J then
            local K=J:FindFirstChild("\84\114\97\110\115\105\116\105\111\110")
            if K then K.Enabled=false end
        end
    end)
end
H()

local function L(M,N)
    local O=N or "\69\97\115\121"
    E:FireServer("\84\101\108\101\112\111\114\116","\87\111\114\107\115\112\97\99\101\46\87\111\114\108\100\115\46\77\105\110\105\103\97\109\101\32\80\97\114\97\100\105\115\101\46\70\97\115\116\84\114\97\118\101\108\46\83\112\97\119\110")
    task.wait(1.5)
    E:FireServer("\83\107\105\112\77\105\110\105\103\97\109\101\67\111\111\108\100\111\119\110",M)
    E:FireServer("\83\116\97\114\116\77\105\110\105\103\97\109\101",M,O)
    task.wait(0.5)
    E:FireServer("\70\105\110\105\115\104\77\105\110\105\103\97\109\101")
end

task.spawn(function()
    local P={
        [1]={name="\82\111\98\111\116\32\67\108\97\119",difficulty="\69\97\115\121"},
        [2]={name="\82\111\98\111\116\32\67\108\97\119",difficulty="\69\97\115\121"},
        [3]={name="\82\111\98\111\116\32\67\108\97\119",difficulty="\69\97\115\121"},
        [4]={name="\80\101\116\32\77\97\116\99\104"},
        [5]={name="\67\97\114\116\32\69\115\99\97\112\101"},
        [6]={name="\82\111\98\111\116\32\67\108\97\119"},
        [7]={name="\82\111\98\111\116\32\67\108\97\119",difficulty="\72\97\114\100"},
        [8]={name="\82\111\98\111\116\32\67\108\97\119",difficulty="\73\110\115\97\110\101"},
        [9]={name="\82\111\98\111\116\32\67\108\97\119",difficulty="\73\110\115\97\110\101"}
    }
    
    while getgenv().Config.AutoMilestones do
        local Q=F:Get()
        local R=Q.QuestsCompleted or {}
        local S=G.Minigames
        local T=0
        local U=0

        for _,V in pairs(S.Tiers) do
            for _,_ in ipairs(V.Levels) do
                U=U+1
                local W="milestone-minigame-"..tostring(U)
                if not R[W] then
                    T=U
                    break
                end
            end
            if T>0 then break end
        end

        if T==0 then
            getgenv().Config.AutoMilestones=false
            break
        end
        
        local X=P[T]
        if X then
            if T==8 or T==9 then
                getgenv().reportTime=60
                getgenv().tryCollectMultipleTimes=false
                getgenv().Config.AutoMilestones=false
                loadstring(game:HttpGet("\104\116\116\112\115\58\47\47\114\97\119\46\103\105\116\104\117\98\117\115\101\114\99\111\110\116\101\110\116\46\99\111\109\47\73\100\105\111\116\72\117\98\47\83\99\114\105\112\116\115\47\114\101\102\115\47\104\101\97\100\115\47\109\97\105\110\47\66\71\83\73\47\65\117\116\111\67\108\97\119\46\108\117\97"))()
            else
                L(X.name,X.difficulty)
            end
        else
            task.wait(5)
        end
        task.wait(1)
    end
end)
