using System;
using System.Collections.Generic;
using System.Text;
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

    // 失败路径（未拿到 Product，如未初始化/商品缺失）下 product 为 null，
    // 必须空判，否则 Lua 侧一旦调用就是 NullReference。
    public PurchasedInfo ConvertToPurchasedInfo(string buykey)
    {
        if (product == null)
        {
            Debug.LogError("IAP: ConvertToPurchasedInfo 时 product 为 null, buykey=" + buykey);
            return null;
        }
        var purchasedInfo = new PurchasedInfo();
        purchasedInfo.Receipt=product.receipt;
        purchasedInfo.TransactionId=product.transactionID;
        purchasedInfo.ProductId=buykey;
        return purchasedInfo;
    }
}

public class IAPManager : DontDestroyOnLoad, IDetailedStoreListener
{
    private static IStoreController m_StoreController;
    private static IExtensionProvider extensionProvider;
    public const string buycoin_base = "cn_item_";
    public static IAPManager Inst;

    // ---------- 单飞锁 ----------
    // 每次 launchBillingFlow 都会 startActivity 一个 ProxyBillingActivity，
    // 连点会在任务栈里叠多个实例；这里做引擎层互斥，回调/超时后释放。
    private const float kPurchaseLockTimeout = 120f; // 面板被系统回收但没回调时的兜底
    private bool purchaseInFlight_ = false;
    private string inFlightProductId_ = "";
    private float lockTime_ = 0f;

    // ---------- 未交付订单落盘 ----------
    // 场景：ProcessPurchase 被引擎回调，但此刻没有任何业务回调挂载
    // （典型＝进程被杀后 Google 在下次 init 重投未消费订单）。
    // 老实现直接 return Complete ⇒ Google 认为已消费，玩家付了钱拿不到东西且永远找不回。
    // 现在先落盘，再 Complete，业务侧用 TakePendingPurchases() 取回补单。
    private const string kPendingPrefsKey = "iap_pending_purchases_v1";
    private const char kRecordSep = '\u001E';
    private const char kFieldSep = '\u001F';
    private static readonly List<PendingPurchase> pending_ = new List<PendingPurchase>();
    private static bool pendingLoaded_ = false;

    private class PendingPurchase
    {
        public string productId;
        public string transactionId;
        public string receipt;
    }

    void Start()
    {
        if (Inst != null && Inst != this)
        {
            Debug.LogWarning("IAP: 重复的 IAPManager 实例，已销毁");
            Destroy(gameObject);
            return;
        }
        Inst = this;
        LoadPending();
        if (pending_.Count > 0)
        {
            Debug.LogWarning("IAP: 存在 " + pending_.Count + " 笔未补发订单，等待业务侧 TakePendingPurchases 处理");
        }
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

    /// <summary>当前是否可发起购买（已初始化且商品表可用）</summary>
    public bool IsReady()
    {
        return m_StoreController != null && m_StoreController.products != null;
    }

    /// <summary>是否已有购买流程在跑</summary>
    public bool IsPurchaseInFlight()
    {
        return purchaseInFlight_;
    }

    /// <summary>未补发订单数量</summary>
    public int GetPendingPurchaseCount()
    {
        LoadPending();
        return pending_.Count;
    }

    /// <summary>
    /// 取走并清空未补发订单，每条格式 "productId#transactionId#receipt"。
    /// 业务侧（Lua）拿到后反查 recharge Id 并发服务器补单。
    /// </summary>
    public string[] TakePendingPurchases()
    {
        LoadPending();
        if (pending_.Count == 0)
        {
            return new string[0];
        }
        var result = new string[pending_.Count];
        for (int i = 0; i < pending_.Count; i++)
        {
            var p = pending_[i];
            result[i] = p.productId + "#" + p.transactionId + "#" + p.receipt;
        }
        pending_.Clear();
        SavePending();
        Debug.LogWarning("IAP: 已取走 " + result.Length + " 笔未补发订单");
        return result;
    }

    public void OnPurchaseFailed(Product product, PurchaseFailureReason failureReason)
    {
        // IStoreListener 要求的过时重载（IAP 5 里实际回调的是带 description 的版本）
        // 这里不再伪造 PurchaseFailureDescription（其构造需要 CartItem），直接就地处理。
        var pid = product != null && product.definition != null ? product.definition.id : "(null)";
        Debug.LogError("IAP 购买失败(legacy) pid=" + pid + " reason=" + failureReason);

        ReleasePurchaseLock();

        var legacyCb = Cb;
        Cb = null;
        SafeInvoke(legacyCb, new IAPResult()
        {
            IsSucc = false,
            product = product,
            failureReason = failureReason,
        });
    }

    public void OnPurchaseFailed(Product product, PurchaseFailureDescription failureDescription)
    {
        var reason = failureDescription != null ? failureDescription.reason : PurchaseFailureReason.Unknown;
        var pid = product != null && product.definition != null ? product.definition.id : "(null)";
        var desc = failureDescription != null ? failureDescription.message : "";
        Debug.LogError("IAP 购买失败 pid=" + pid + " reason=" + reason + " desc=" + desc);

        ReleasePurchaseLock();

        var cb = Cb;
        Cb = null;
        SafeInvoke(cb, new IAPResult()
        {
            IsSucc = false,
            product = product,
            failureReason = reason,
            failureDescription = failureDescription,
        });
    }

    public void OnInitialized(IStoreController controller, IExtensionProvider extensions)
    {
        m_StoreController = controller;
        extensionProvider = extensions;
        Debug.Log("IAP 初始化成功！");
    }

    private Action<IAPResult> Cb;

    public void BuyItem1(int payItemId, int price, Action<IAPResult> cb)
    {
        if (price == 0)
        {
            // 0 元礼包：product 为 null，属业务侧白名单逻辑，不下发 IAP
            SafeInvoke(cb, new IAPResult()
            {
                IsSucc = true,
                product = null,

            });
            return;
        }

        if (!IsReady())
        {
            FailAndInvoke(cb, PurchaseFailureReason.PurchasingUnavailable, "IAP 未初始化完成（m_StoreController 为空）", true);
            return;
        }

        var buyKey = buycoin_base + price;
        var product = m_StoreController.products.WithID(buyKey);
        if (product == null || product.definition == null)
        {
            FailAndInvoke(cb, PurchaseFailureReason.ProductUnavailable,
                "商品表中没有 " + buyKey + "（price=" + price + "，请核对 GooglePlay 商品配置）", true);
            return;
        }
        if (!product.availableToPurchase)
        {
            FailAndInvoke(cb, PurchaseFailureReason.ProductUnavailable, "商品当前不可购买 " + buyKey, true);
            return;
        }

        if (!TryEnterPurchaseFlow(buyKey))
        {
            // 注意：这里不能释放锁，锁属于另一个在途流程
            FailAndInvoke(cb, PurchaseFailureReason.ExistingPurchasePending, "上一个购买流程尚未结束，请稍后再试", false);
            return;
        }

        // 回调在拿到锁之后才挂，避免并发调用把在途订单的回调覆盖掉
        this.Cb = cb;
        try
        {
            m_StoreController.InitiatePurchase(product);
        }
        catch (Exception e)
        {
            Cb = null;
            FailAndInvoke(cb, PurchaseFailureReason.Unknown, "InitiatePurchase 抛异常: " + e.Message, true);
            return;
        }
        Debug.Log("IAP BuyItem1" + buycoin_base + "--payItemId" + payItemId + "--price:" + price);
    }

    public void BuyItem(string pruductid)
    {
        if (string.IsNullOrEmpty(pruductid))
        {
            Debug.LogError("IAP BuyItem: pruductid 为空");
            return;
        }
        if (!IsReady())
        {
            Debug.LogError("IAP BuyItem: 未初始化完成，忽略 " + pruductid);
            return;
        }
        var product = m_StoreController.products.WithID(pruductid);
        if (product == null || product.definition == null)
        {
            Debug.LogError("IAP BuyItem: 商品表中没有 " + pruductid);
            return;
        }
        if (!TryEnterPurchaseFlow(pruductid))
        {
            Debug.LogError("IAP BuyItem: 上一个购买流程尚未结束，忽略 " + pruductid);
            return;
        }
        try
        {
            m_StoreController.InitiatePurchase(product);
        }
        catch (Exception e)
        {
            ReleasePurchaseLock();
            Debug.LogError("IAP BuyItem: InitiatePurchase 抛异常 " + e.Message);
        }
    }

    public void OnInitializeFailed(InitializationFailureReason error)
    {
        Debug.LogError($"IAP 初始化失败: {error}");
    }

    public void OnInitializeFailed(InitializationFailureReason error, string message)
    {
        Debug.LogError($"IAP 初始化失败: {error} msg={message}");

    }

    public PurchaseProcessingResult ProcessPurchase(PurchaseEventArgs args)
    {
        var product = args != null ? args.purchasedProduct : null;
        if (product == null)
        {
            Debug.LogError("IAP: ProcessPurchase 收到空 product，忽略");
            ReleasePurchaseLock();
            return PurchaseProcessingResult.Complete;
        }

        var pid = product.definition != null ? product.definition.id : "";
        Debug.Log($"购买成功 需要验单: {product.hasReceipt} --> {pid} --> {product.transactionID} --> receipt:{product.receipt}");

        // 判断这笔是不是当前这次购买流程的：不是就说明是 Google 重投的历史未消费订单
        // （进程被杀 / 老版本静默 Complete 之前残留），此时没有业务回调可交付。
        var matched = purchaseInFlight_ && !string.IsNullOrEmpty(inFlightProductId_) && inFlightProductId_ == pid;
        ReleasePurchaseLock();

        if (!matched)
        {
            PersistPending(product, "无在途购买，判定为历史重投订单");
            // 仍返回 Complete：避免 unconsumed 3 天后被 Google 自动退款；
            // 落盘记录 + TakePendingPurchases 负责业务补发。
            return PurchaseProcessingResult.Complete;
        }

        var cb = Cb;
        Cb = null;
        if (cb != null)
        {
            SafeInvoke(cb, new IAPResult()
            {
                IsSucc = true,
                product = product,

            });
        }
        else
        {
            // 在途但业务回调已丢，同样落盘防止丢单
            PersistPending(product, "在途购买但业务回调为空");
        }
        return PurchaseProcessingResult.Complete;
    }

    // ---------------- 内部工具 ----------------

    private bool TryEnterPurchaseFlow(string productId)
    {
        if (purchaseInFlight_)
        {
            // 超时兜底：面板被系统回收但没回调时锁不能永久占住
            if (Time.unscaledTime - lockTime_ < kPurchaseLockTimeout)
            {
                return false;
            }
            Debug.LogWarning("IAP: 购买锁超时（" + kPurchaseLockTimeout + "s），强制释放");
        }
        purchaseInFlight_ = true;
        inFlightProductId_ = productId;
        lockTime_ = Time.unscaledTime;
        return true;
    }

    private void ReleasePurchaseLock()
    {
        purchaseInFlight_ = false;
        inFlightProductId_ = "";
        lockTime_ = 0f;
    }

    private void FailAndInvoke(Action<IAPResult> cb, PurchaseFailureReason reason, string message, bool releaseLock)
    {
        Debug.LogError("IAP 发起购买失败: " + message);
        if (releaseLock)
        {
            ReleasePurchaseLock();
            Cb = null;
        }
        SafeInvoke(cb, new IAPResult()
        {
            IsSucc = false,
            product = null,
            failureReason = reason,
        });
    }

    private static void SafeInvoke(Action<IAPResult> cb, IAPResult result)
    {
        if (cb == null)
        {
            return;
        }
        try
        {
            cb(result);
        }
        catch (Exception e)
        {
            Debug.LogError("IAP: 业务回调抛异常 " + e);
        }
    }

    private static void PersistPending(Product product, string why)
    {
        LoadPending();
        var pid = product.definition != null ? product.definition.id : "";
        var tid = product.transactionID ?? "";
        for (int i = 0; i < pending_.Count; i++)
        {
            if (pending_[i].productId == pid && pending_[i].transactionId == tid)
            {
                return; // 同一笔不重复记
            }
        }
        pending_.Add(new PendingPurchase()
        {
            productId = pid,
            transactionId = tid,
            receipt = product.receipt ?? "",
        });
        SavePending();
        Debug.LogWarning("IAP: 订单已落盘待补发 pid=" + pid + " tid=" + tid + " 原因=" + why);
    }

    private static void LoadPending()
    {
        if (pendingLoaded_)
        {
            return;
        }
        pendingLoaded_ = true;
        pending_.Clear();
        var raw = PlayerPrefs.GetString(kPendingPrefsKey, string.Empty);
        if (string.IsNullOrEmpty(raw))
        {
            return;
        }
        var records = raw.Split(kRecordSep);
        for (int i = 0; i < records.Length; i++)
        {
            if (string.IsNullOrEmpty(records[i]))
            {
                continue;
            }
            var f = records[i].Split(kFieldSep);
            if (f.Length < 3)
            {
                continue;
            }
            pending_.Add(new PendingPurchase()
            {
                productId = f[0],
                transactionId = f[1],
                receipt = f[2],
            });
        }
    }

    private static void SavePending()
    {
        var sb = new StringBuilder();
        for (int i = 0; i < pending_.Count; i++)
        {
            if (i > 0)
            {
                sb.Append(kRecordSep);
            }
            sb.Append(pending_[i].productId).Append(kFieldSep)
              .Append(pending_[i].transactionId).Append(kFieldSep)
              .Append(pending_[i].receipt);
        }
        PlayerPrefs.SetString(kPendingPrefsKey, sb.ToString());
        PlayerPrefs.Save();
    }
}
