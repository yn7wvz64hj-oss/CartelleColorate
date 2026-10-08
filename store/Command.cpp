#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <appmodel.h>
#include <string>
#include <new>

// Stable CLSID: keep the manifest and this source in sync.
const CLSID CommandId = {0xb0ccf71b,0xa843,0x4d3a,{0xa6,0x2c,0x09,0xbe,0x0d,0x36,0x43,0x71}};
static LONG objects = 0;
static HMODULE module;
static std::wstring PackageDirectory() {
    wchar_t path[32768]; DWORD length = GetModuleFileNameW(module, path, 32768);
    if (!length || length == 32768) return L"";
    std::wstring result(path, length); return result.substr(0, result.find_last_of(L"\\"));
}
static std::wstring Quote(const std::wstring& value) {
    std::wstring result=L"\""; size_t slashes=0;
    for (wchar_t c : value) {
        if (c==L'\\') {++slashes; continue;}
        if (c==L'"') result.append(slashes*2+1,L'\\');
        else result.append(slashes,L'\\');
        slashes=0; result+=c;
    }
    result.append(slashes*2,L'\\'); return result+L"\"";
}
class Command final : public IExplorerCommand {
    LONG refs=1;
public:
    Command(){InterlockedIncrement(&objects);} ~Command(){InterlockedDecrement(&objects);}
    IFACEMETHODIMP QueryInterface(REFIID iid,void** p) override {
        if (!p) return E_POINTER; *p=nullptr;
        if (iid==IID_IUnknown || iid==__uuidof(IExplorerCommand)) {*p=static_cast<IExplorerCommand*>(this); AddRef(); return S_OK;} return E_NOINTERFACE;
    }
    IFACEMETHODIMP_(ULONG) AddRef() override{return InterlockedIncrement(&refs);}
    IFACEMETHODIMP_(ULONG) Release() override{ULONG r=InterlockedDecrement(&refs);if(!r)delete this;return r;}
    IFACEMETHODIMP GetTitle(IShellItemArray*,LPWSTR* p) override {
        return SHStrDupW(PRIMARYLANGID(GetUserDefaultUILanguage())==LANG_ITALIAN ? L"Nova Prism - Cambia colore" : L"Nova Prism - Change folder color",p);
    }
    IFACEMETHODIMP GetIcon(IShellItemArray*,LPWSTR* p) override{return SHStrDupW((PackageDirectory()+L"\\Assets\\NovaPrism.ico").c_str(),p);}
    IFACEMETHODIMP GetToolTip(IShellItemArray*,LPWSTR* p) override {if(p)*p=nullptr;return E_NOTIMPL;}
    IFACEMETHODIMP GetCanonicalName(GUID* p) override {if(!p)return E_POINTER;*p=CommandId;return S_OK;}
    IFACEMETHODIMP GetState(IShellItemArray* items,BOOL,EXPCMDSTATE* p) override {
        if(!p)return E_POINTER;*p=ECS_DISABLED;DWORD count=0;
        if(items && SUCCEEDED(items->GetCount(&count)) && count) *p=ECS_ENABLED; return S_OK;
    }
    IFACEMETHODIMP Invoke(IShellItemArray* items,IBindCtx*) override {
        if(!items)return E_INVALIDARG;DWORD count=0;HRESULT hr=items->GetCount(&count);if(FAILED(hr))return hr;
        std::wstring arguments;
        for(DWORD i=0;i<count;i++) {
            IShellItem* item=nullptr;LPWSTR path=nullptr;
            hr=items->GetItemAt(i,&item);if(FAILED(hr))return hr;
            SFGAOF attrs=0;hr=item->GetAttributes(SFGAO_FOLDER|SFGAO_FILESYSTEM,&attrs);
            if(SUCCEEDED(hr) && (attrs&(SFGAO_FOLDER|SFGAO_FILESYSTEM))==(SFGAO_FOLDER|SFGAO_FILESYSTEM))hr=item->GetDisplayName(SIGDN_FILESYSPATH,&path);
            else hr=E_INVALIDARG;
            item->Release();if(FAILED(hr))return hr;
            if(!arguments.empty())arguments+=L" ";arguments+=Quote(path);CoTaskMemFree(path);
        }
        if(arguments.empty() || arguments.size()>30000)return E_INVALIDARG;
        // Activate through the registered AUMID to retain package identity.
        UINT32 size=0;LONG error=GetCurrentPackageFamilyName(&size,nullptr);
        if(error!=ERROR_INSUFFICIENT_BUFFER)return HRESULT_FROM_WIN32(error);
        std::wstring family(size,L'\0');error=GetCurrentPackageFamilyName(&size,&family[0]);
        if(error!=ERROR_SUCCESS)return HRESULT_FROM_WIN32(error);family.resize(size-1);
        IApplicationActivationManager* activation=nullptr;
        hr=CoCreateInstance(CLSID_ApplicationActivationManager,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&activation));
        if(FAILED(hr))return hr;DWORD pid=0;
        hr=activation->ActivateApplication((family+L"!NovaPrism").c_str(),arguments.c_str(),AO_NONE,&pid);
        activation->Release();return hr;
    }
    IFACEMETHODIMP GetFlags(EXPCMDFLAGS* p) override {if(!p)return E_POINTER;*p=ECF_DEFAULT;return S_OK;}
    IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** p) override {if(p)*p=nullptr;return E_NOTIMPL;}
};
class Factory final : public IClassFactory {
    LONG refs=1;
public:
    Factory(){InterlockedIncrement(&objects);}~Factory(){InterlockedDecrement(&objects);}
    IFACEMETHODIMP QueryInterface(REFIID iid,void** p) override {if(!p)return E_POINTER;*p=nullptr;if(iid==IID_IUnknown||iid==IID_IClassFactory){*p=static_cast<IClassFactory*>(this);AddRef();return S_OK;}return E_NOINTERFACE;}
    IFACEMETHODIMP_(ULONG) AddRef() override{return InterlockedIncrement(&refs);}
    IFACEMETHODIMP_(ULONG) Release() override{ULONG r=InterlockedDecrement(&refs);if(!r)delete this;return r;}
    IFACEMETHODIMP CreateInstance(IUnknown* outer,REFIID iid,void** p) override {if(outer)return CLASS_E_NOAGGREGATION;Command* c=new(std::nothrow)Command();if(!c)return E_OUTOFMEMORY;HRESULT hr=c->QueryInterface(iid,p);c->Release();return hr;}
    IFACEMETHODIMP LockServer(BOOL lock) override {if(lock)InterlockedIncrement(&objects);else InterlockedDecrement(&objects);return S_OK;}
};
BOOL WINAPI DllMain(HINSTANCE h,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH){module=h;DisableThreadLibraryCalls(h);}return TRUE;}
STDAPI DllCanUnloadNow(){return objects==0?S_OK:S_FALSE;}
STDAPI DllGetClassObject(REFCLSID clsid,REFIID iid,void** p){if(clsid!=CommandId)return CLASS_E_CLASSNOTAVAILABLE;Factory* f=new(std::nothrow)Factory();if(!f)return E_OUTOFMEMORY;HRESULT hr=f->QueryInterface(iid,p);f->Release();return hr;}
