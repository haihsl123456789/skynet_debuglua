local const={}

const.BulletType = {
    BTNormal = 0,
    BTNormal2 = 1,
    BTNormal3 = 2,
    -- BTDrill = 3,		
    BTMAX = 4,
}

const.FishType = {
    FTNormal = 0  ,   
    FTSimilar = 1	,  
    FTLightning = 2  ,
    FTFreeze = 3     ,
    FTLocalBomb = 4  ,
    FTDrill = 5    ,  
    FTBomb  = 6     , 
}

const.Ret = {
    Ok = 0,
    SessionError = 1,
    Error = 100,
}

return const