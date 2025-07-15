namespace SDK
{
    // 初始化参数
    public struct SDKInitArgs
    {
        public int appid;
        public string appkey;
        public string privateKey;
    }
    //支付参数
    public struct SDKPayArgs
    {
        public string rechargeId;
        public int showType;
        public int productId;
        public string productName;
        public string productDesc;
        public string price;
        public string currencyType;
        public int ratio;
        public int buyNum;
        public int coinNum;
        public string zoneId;
        public string serverID;
        public string serverName;
        public string accounted;
        public string roleID;
        public string roleName;
        public int roleLevel;
        public string vip;
        public string guildID;
        public string orderID;
        public string payNotifyUrl;
        public string extension;
    }
    //数据上报参数
    public struct SDKSubmitExtraDataArgs
    {
        public int dataType;
        public int serverID;
        public string serverName;
        public string zoneID;
        public string zoneName;
        public string roleID;
        public string roleName;
        public string roleLevel;
        public string guildID;
        public string Vip;
        public int moneyNum;
        public string roleCreateTime;
        public string roleLevelUpTime;
    }
}



