namespace UnrealM
{
    public abstract class ActionNode
    {
        protected ActionNode()
        {
        }

        internal abstract bool Update(ActionSequence actionSequence);

        internal abstract void Release();
    }
}