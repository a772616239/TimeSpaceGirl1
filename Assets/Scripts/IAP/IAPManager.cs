using System;
using GameCore;
using GameLogic;
using UnityEngine;
using UnityEngine.Purchasing;
using UnityEngine.Purchasing.Extension;

public partial class PurchasedInfo
{

    private string receipt_ = "";

    public string Receipt
    {
        get { return receipt_; }
        set { receipt_ = value; }
    }

    private string transactionId_ = "";

    public string TransactionId
    {
        get { return transactionId_; }
        set { transactionId_ = value; }
    }

    private string productId_ = "";

    public string ProductId
    {
        get { return productId_; }
        set { productId_ = value; }
    }
}

public class IAPResult
{
    public bool IsSucc = false;
    public Product product;
    public PurchaseFailureReason failureReason;
    public PurchaseFailureDescription failureDescription;

    public PurchasedInfo ConvertToPurchasedInfo(string buykey)
    {
        var purchasedInfo = new PurchasedInfo();
        purchasedInfo.Receipt=product.receipt;
        purchasedInfo.TransactionId=product.transactionID;
        purchasedInfo.ProductId=buykey;
        return purchasedInfo;
    }
}
public class IAPManager : DontDestroyOnLoad, IStoreListener
{
    private static IStoreController m_StoreController;
    private static IExtensionProvider extensionProvider;
    public const string buycoin_base = "cn_item_";
    public static IAPManager Inst;
    void Start()
    {
        Inst = this;
        InitializePurchasing();
    }
    

    private void InitializePurchasing()
    {
        var builder = ConfigurationBuilder.Instance(StandardPurchasingModule.Instance());

        //Add products that will be purchasable and indicate its type.
        builder.AddProduct(buycoin_base + 6, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 12, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 18, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 30, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 50, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 60, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 66, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 68, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 98, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 128, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 198, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 288, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 328, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 388, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 448, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 488, ProductType.Consumable);
        builder.AddProduct(buycoin_base + 648, ProductType.Consumable);
        UnityPurchasing.Initialize(this, builder);
    }

    public void OnPurchaseFailed(Product product, PurchaseFailureReason failureReason)
    {
        Debug.Log($"Purchase failed - Product: '{product.definition.id}', PurchaseFailureReason: {failureReason}");
        if (this.Cb!=null)
        {
            Cb(new IAPResult()
            {
                IsSucc = false,
                product = product,
            });
        }

    }

    public void OnInitialized(IStoreController controller, IExtensionProvider extensions)
    {
        m_StoreController = controller;
        extensionProvider = extensions;
        Debug.Log("IAP 初始化成功！");
    }

    private Action<IAPResult> Cb;
    public  void BuyItem1(int payItemId,int price,Action<IAPResult> cb)
    {
        this.Cb = cb;
        if (price==0)
        {
            Cb(new IAPResult()
            {
                IsSucc = true,
                product = null,

            });
            return;
        }
        string buyKey = buycoin_base + price;
        if (m_StoreController != null)
        {
            var product= m_StoreController.products.WithID(buyKey);
            m_StoreController.InitiatePurchase(product);
        }
        Debug.Log("IAP BuyItem1"+buycoin_base+"--payItemId"+payItemId+"--price:"+price);
    }
    
    public  void BuyItem(string pruductid)
    {
        // tcs  = new TaskCompletionSource<IAPResult>();
        var product= m_StoreController.products.WithID(pruductid);

        m_StoreController.InitiatePurchase(product);
    }

    public void OnInitializeFailed(InitializationFailureReason error)
    {
        Debug.LogError($"IAP 初始化失败: {error}");
    }

    public void OnInitializeFailed(InitializationFailureReason error, string message)
    {
        Debug.LogError($"IAP 初始化失败: {error}");

    }

    public PurchaseProcessingResult ProcessPurchase(PurchaseEventArgs args)
    {
        var product = args.purchasedProduct;
        Debug.Log($"购买成功 需要验单: {product.hasReceipt} --> {product.definition.id} --> {product.transactionID} --> receipt:{product.receipt}");
        //Add the purchased product to the players inventory
        Debug.Log($"Purchase Complete - Product: {product.definition.id}");
        if (this.Cb!=null)
        {
            Cb(new IAPResult()
            {
                IsSucc = true,
                product = product,

            });
        }
        //We return Complete, informing IAP that the processing on our side is done and the transaction can be closed.
        return PurchaseProcessingResult.Complete;
    }
}