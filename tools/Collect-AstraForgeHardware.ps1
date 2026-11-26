[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$DxDiagReportPath
)

$ErrorActionPreference = 'Stop'

$nativeSource = @'
using System;
using System.Runtime.InteropServices;

public static class VictoryHardwareProbe
{
    [StructLayout(LayoutKind.Sequential)]
    public struct MemoryStatus
    {
        public uint Length;
        public uint MemoryLoad;
        public ulong TotalPhysical;
        public ulong AvailablePhysical;
        public ulong TotalPageFile;
        public ulong AvailablePageFile;
        public ulong TotalVirtual;
        public ulong AvailableVirtual;
        public ulong AvailableExtendedVirtual;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct AdapterDescription1
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string Description;
        public uint VendorId;
        public uint DeviceId;
        public uint SubSysId;
        public uint Revision;
        public ulong DedicatedVideoMemory;
        public ulong DedicatedSystemMemory;
        public ulong SharedSystemMemory;
        public long AdapterLuid;
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct VideoMemoryInfo
    {
        public ulong Budget;
        public ulong CurrentUsage;
        public ulong AvailableForReservation;
        public ulong CurrentReservation;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct ShaderModelInfo { public uint HighestShaderModel; }

    [StructLayout(LayoutKind.Sequential)]
    public struct Options1Info
    {
        public int WaveOps;
        public uint WaveLaneCountMin;
        public uint WaveLaneCountMax;
        public uint TotalLaneCount;
        public int ExpandedComputeResourceStates;
        public int Int64ShaderOps;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Options7Info
    {
        public uint MeshShaderTier;
        public uint SamplerFeedbackTier;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Options5Info
    {
        public int SrvOnlyTiledResourceTier3;
        public uint RenderPassesTier;
        public uint RaytracingTier;
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int EnumAdapters1Delegate(IntPtr self, uint index, out IntPtr adapter);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetDescription1Delegate(IntPtr self, out AdapterDescription1 description);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int QueryInterfaceDelegate(IntPtr self, ref Guid iid, out IntPtr result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int QueryVideoMemoryInfoDelegate(IntPtr self, uint node, uint segment, out VideoMemoryInfo info);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int CheckFeatureSupportDelegate(IntPtr self, int feature, IntPtr data, uint size);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetPhysicallyInstalledSystemMemory(out ulong totalMemoryInKilobytes);

    [DllImport("kernel32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsProcessorFeaturePresent(uint feature);

    [DllImport("dxgi.dll", ExactSpelling = true)]
    private static extern int CreateDXGIFactory1(ref Guid iid, out IntPtr factory);

    [DllImport("d3d12.dll", ExactSpelling = true)]
    private static extern int D3D12CreateDevice(IntPtr adapter, uint minimumFeatureLevel, ref Guid iid, out IntPtr device);

    private static IntPtr Method(IntPtr instance, int slot)
    {
        IntPtr table = Marshal.ReadIntPtr(instance);
        return Marshal.ReadIntPtr(table, slot * IntPtr.Size);
    }

    private static T Delegate<T>(IntPtr instance, int slot) where T : class
    {
        return (T)(object)Marshal.GetDelegateForFunctionPointer(Method(instance, slot), typeof(T));
    }

    public static MemoryStatus GetMemoryStatus()
    {
        MemoryStatus status = new MemoryStatus();
        status.Length = (uint)Marshal.SizeOf(typeof(MemoryStatus));
        if (!GlobalMemoryStatusEx(ref status))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        return status;
    }

    public static ulong GetInstalledPhysicalMemoryBytes()
    {
        ulong totalMemoryInKilobytes;
        if (!GetPhysicallyInstalledSystemMemory(out totalMemoryInKilobytes)) return 0;
        return totalMemoryInKilobytes * 1024UL;
    }

    public static bool SupportsAvx2()
    {
        // PF_AVX2_INSTRUCTIONS_AVAILABLE (40); Windows reports this only when OS state support is enabled too.
        return IsProcessorFeaturePresent(40);
    }

    public static AdapterDescription1[] GetAdapters()
    {
        Guid factoryIid = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
        IntPtr factory = IntPtr.Zero;
        int hr = CreateDXGIFactory1(ref factoryIid, out factory);
        if (hr < 0) Marshal.ThrowExceptionForHR(hr);
        var results = new System.Collections.Generic.List<AdapterDescription1>();
        try
        {
            var enumerate = Delegate<EnumAdapters1Delegate>(factory, 12);
            for (uint i = 0; i < 32; i++)
            {
                IntPtr adapter;
                hr = enumerate(factory, i, out adapter);
                if (hr == unchecked((int)0x887A0002)) break;
                if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                try
                {
                    AdapterDescription1 description;
                    hr = Delegate<GetDescription1Delegate>(adapter, 10)(adapter, out description);
                    if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                    results.Add(description);
                }
                finally { Marshal.Release(adapter); }
            }
        }
        finally { Marshal.Release(factory); }
        return results.ToArray();
    }

    public static VideoMemoryInfo? GetLocalBudget(AdapterDescription1 description)
    {
        Guid factoryIid = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
        Guid adapter3Iid = new Guid("645967A4-1392-4310-A798-8053CE3E93FD");
        IntPtr factory = IntPtr.Zero;
        int hr = CreateDXGIFactory1(ref factoryIid, out factory);
        if (hr < 0) Marshal.ThrowExceptionForHR(hr);
        IntPtr selected = IntPtr.Zero;
        try
        {
            var enumerate = Delegate<EnumAdapters1Delegate>(factory, 12);
            for (uint i = 0; i < 32; i++)
            {
                IntPtr adapter;
                hr = enumerate(factory, i, out adapter);
                if (hr == unchecked((int)0x887A0002)) break;
                if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                AdapterDescription1 candidate;
                try
                {
                    hr = Delegate<GetDescription1Delegate>(adapter, 10)(adapter, out candidate);
                    if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                    if (candidate.VendorId == description.VendorId && candidate.DeviceId == description.DeviceId && candidate.AdapterLuid == description.AdapterLuid)
                    {
                        hr = Delegate<QueryInterfaceDelegate>(adapter, 0)(adapter, ref adapter3Iid, out selected);
                        if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                        break;
                    }
                }
                finally { Marshal.Release(adapter); }
            }
            if (selected == IntPtr.Zero) return null;
            VideoMemoryInfo info;
            hr = Delegate<QueryVideoMemoryInfoDelegate>(selected, 14)(selected, 0, 0, out info);
            if (hr < 0) Marshal.ThrowExceptionForHR(hr);
            return info;
        }
        finally
        {
            if (selected != IntPtr.Zero) Marshal.Release(selected);
            Marshal.Release(factory);
        }
    }

    private static IntPtr AllocateZeroed(int size)
    {
        IntPtr pointer = Marshal.AllocHGlobal(size);
        Marshal.Copy(new byte[size], 0, pointer, size);
        return pointer;
    }

    public static System.Collections.Generic.Dictionary<string, object> GetD3D12Features(AdapterDescription1 description)
    {
        var output = new System.Collections.Generic.Dictionary<string, object>();
        IntPtr factory = IntPtr.Zero;
        IntPtr adapter = IntPtr.Zero;
        IntPtr device = IntPtr.Zero;
        try
        {
            Guid factoryIid = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
            int hr = CreateDXGIFactory1(ref factoryIid, out factory);
            if (hr < 0) Marshal.ThrowExceptionForHR(hr);
            var enumerate = Delegate<EnumAdapters1Delegate>(factory, 12);
            for (uint i = 0; i < 32; i++)
            {
                IntPtr candidateAdapter;
                hr = enumerate(factory, i, out candidateAdapter);
                if (hr == unchecked((int)0x887A0002)) break;
                if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                AdapterDescription1 candidate;
                try
                {
                    hr = Delegate<GetDescription1Delegate>(candidateAdapter, 10)(candidateAdapter, out candidate);
                    if (hr < 0) Marshal.ThrowExceptionForHR(hr);
                    if (candidate.VendorId == description.VendorId && candidate.DeviceId == description.DeviceId && candidate.AdapterLuid == description.AdapterLuid)
                    {
                        adapter = candidateAdapter;
                        candidateAdapter = IntPtr.Zero;
                        break;
                    }
                }
                finally { if (candidateAdapter != IntPtr.Zero) Marshal.Release(candidateAdapter); }
            }
            if (adapter == IntPtr.Zero) throw new InvalidOperationException("DXGI adapter disappeared before D3D12 feature query.");

            Guid deviceIid = new Guid("189819f1-1db6-4b57-be54-1821339b85f7");
            hr = D3D12CreateDevice(adapter, 0xb000, ref deviceIid, out device);
            if (hr < 0) Marshal.ThrowExceptionForHR(hr);
            // ID3D12Device::CheckFeatureSupport is slot 13 after IUnknown and ID3D12Object.
            var check = Delegate<CheckFeatureSupportDelegate>(device, 13);

            for (uint model = 0x68; model >= 0x60; model--)
            {
                int size = Marshal.SizeOf(typeof(ShaderModelInfo));
                IntPtr data = AllocateZeroed(size);
                try
                {
                    Marshal.StructureToPtr(new ShaderModelInfo { HighestShaderModel = model }, data, false);
                    hr = check(device, 7, data, (uint)size); // D3D12_FEATURE_SHADER_MODEL
                    if (hr >= 0)
                    {
                        var shader = (ShaderModelInfo)Marshal.PtrToStructure(data, typeof(ShaderModelInfo));
                        output["ShaderModel"] = String.Format("{0}.{1}", shader.HighestShaderModel >> 4, shader.HighestShaderModel & 15);
                        break;
                    }
                }
                finally { Marshal.FreeHGlobal(data); }
                if (model == 0x60) break;
            }

            int options1Size = Marshal.SizeOf(typeof(Options1Info));
            IntPtr options1Data = AllocateZeroed(options1Size);
            try
            {
                hr = check(device, 8, options1Data, (uint)options1Size); // D3D12_FEATURE_D3D12_OPTIONS1
                if (hr >= 0)
                {
                    var options = (Options1Info)Marshal.PtrToStructure(options1Data, typeof(Options1Info));
                    output["WaveOps"] = options.WaveOps != 0;
                    output["WaveLaneCountMin"] = options.WaveLaneCountMin;
                    output["WaveLaneCountMax"] = options.WaveLaneCountMax;
                }
            }
            finally { Marshal.FreeHGlobal(options1Data); }

            int options7Size = Marshal.SizeOf(typeof(Options7Info));
            IntPtr options7Data = AllocateZeroed(options7Size);
            try
            {
                hr = check(device, 32, options7Data, (uint)options7Size); // D3D12_FEATURE_D3D12_OPTIONS7
                if (hr >= 0)
                {
                    var options = (Options7Info)Marshal.PtrToStructure(options7Data, typeof(Options7Info));
                    output["MeshShaderTierValue"] = options.MeshShaderTier;
                    output["MeshShaderTier"] = options.MeshShaderTier == 10 ? "Tier 1" : (options.MeshShaderTier == 0 ? "Not supported" : String.Format("Unknown ({0})", options.MeshShaderTier));
                    output["SamplerFeedbackTierValue"] = options.SamplerFeedbackTier;
                    output["SamplerFeedbackTier"] = options.SamplerFeedbackTier == 100 ? "Tier 1.0" : (options.SamplerFeedbackTier == 90 ? "Tier 0.9" : (options.SamplerFeedbackTier == 0 ? "Not supported" : String.Format("Unknown ({0})", options.SamplerFeedbackTier)));
                }
            }
            finally { Marshal.FreeHGlobal(options7Data); }

            int options5Size = Marshal.SizeOf(typeof(Options5Info));
            IntPtr options5Data = AllocateZeroed(options5Size);
            try
            {
                hr = check(device, 27, options5Data, (uint)options5Size); // D3D12_FEATURE_D3D12_OPTIONS5
                if (hr >= 0)
                {
                    var options = (Options5Info)Marshal.PtrToStructure(options5Data, typeof(Options5Info));
                    output["RaytracingTierValue"] = options.RaytracingTier;
                    output["RaytracingTier"] = options.RaytracingTier == 10 ? "Tier 1.0" : (options.RaytracingTier == 11 ? "Tier 1.1" : (options.RaytracingTier == 12 ? "Tier 1.2" : "Not supported"));
                }
            }
            finally { Marshal.FreeHGlobal(options5Data); }
            return output;
        }
        finally
        {
            if (device != IntPtr.Zero) Marshal.Release(device);
            if (adapter != IntPtr.Zero) Marshal.Release(adapter);
            if (factory != IntPtr.Zero) Marshal.Release(factory);
        }
    }

}
'@

if (-not ('VictoryHardwareProbe' -as [type])) {
    Add-Type -TypeDefinition $nativeSource -Language CSharp
}

function ConvertTo-GiB([UInt64]$Bytes) {
    [Math]::Round(($Bytes / 1GB), 2)
}

$cpuName = $null
$physicalCores = $null
$logicalProcessors = [Environment]::ProcessorCount
$memoryModules = @()
try {
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
    $cpuName = ($cpu | Select-Object -First 1 -ExpandProperty Name).Trim()
    $physicalCores = ($cpu | Measure-Object -Property NumberOfCores -Sum).Sum
    $logicalProcessors = ($cpu | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
} catch {
    $cpuKey = Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction SilentlyContinue
    if ($cpuKey) { $cpuName = ([string]$cpuKey.ProcessorNameString).Trim() }
    if ($cpuName -match '(\d+)-Core Processor') { $physicalCores = [int]$Matches[1] }
}
try {
    $memoryModules = @(Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{
            CapacityGiB = ConvertTo-GiB ([UInt64]$_.Capacity)
            SpeedMHz = $_.Speed
            ConfiguredClockSpeedMHz = $_.ConfiguredClockSpeed
            Manufacturer = ([string]$_.Manufacturer).Trim()
            PartNumber = ([string]$_.PartNumber).Trim()
        }
    })
} catch { $memoryModules = @() }

$osKey = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$osDisplayName = [string]$osKey.ProductName
if ([int]$osKey.CurrentBuild -ge 22000 -and $osDisplayName -match '^Windows 10') {
    $osDisplayName = $osDisplayName -replace '^Windows 10', 'Windows 11'
}
$dxDiag = $null
if ($DxDiagReportPath -and (Test-Path -LiteralPath $DxDiagReportPath)) {
    $dxDiagText = Get-Content -LiteralPath $DxDiagReportPath -Raw
    $directXLine = [regex]::Match($dxDiagText, '(?m)^\s*DirectX Version:\s*(.+)$').Groups[1].Value.Trim()
    $ddiLine = [regex]::Match($dxDiagText, '(?m)^\s*DDI Version:\s*(.+)$').Groups[1].Value.Trim()
    $featureLine = [regex]::Match($dxDiagText, '(?m)^\s*Feature Levels:\s*(.+)$').Groups[1].Value.Trim()
    $dxDiag = [ordered]@{ DirectXVersion = $directXLine; DdiVersion = $ddiLine; FeatureLevels = $featureLine }
}
$d3d12 = [ordered]@{
    DirectXVersion = if ($dxDiag) { $dxDiag.DirectXVersion } else { 'Not read; pass -DxDiagReportPath to include dxdiag output.' }
    DdiVersion = if ($dxDiag) { $dxDiag.DdiVersion } else { $null }
    FeatureLevels = if ($dxDiag) { $dxDiag.FeatureLevels } else { $null }
    ShaderModel = $null
    WaveOps = $null
    WaveLaneCountMin = $null
    WaveLaneCountMax = $null
    MeshShaderTier = $null
    MeshShaderTierValue = $null
    SamplerFeedbackTier = $null
    SamplerFeedbackTierValue = $null
    RaytracingTier = $null
    RaytracingTierValue = $null
}
$memory = [VictoryHardwareProbe]::GetMemoryStatus()
$installedPhysicalMemory = [VictoryHardwareProbe]::GetInstalledPhysicalMemoryBytes()
$adapters = @([VictoryHardwareProbe]::GetAdapters())
$firstDxgiAdapter = $adapters | Select-Object -First 1
$nvidia = $adapters | Where-Object { $_.VendorId -eq 4318 } | Select-Object -First 1
$dxgiBudget = $null
$dxgiBudgetError = $null
if ($nvidia) {
    try {
        $dxgiBudget = [VictoryHardwareProbe]::GetLocalBudget($nvidia)
    } catch {
        $dxgiBudgetError = $_.Exception.Message
    }
    try {
        $features = [VictoryHardwareProbe]::GetD3D12Features($nvidia)
        foreach ($key in $features.Keys) { $d3d12[$key] = $features[$key] }
    } catch {
        $d3d12.FeatureQueryError = $_.Exception.Message
    }
}

$nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
$gpuSmi = $null
$bar1TotalMiB = $null
$bar1UsedMiB = $null
$bar1FreeMiB = $null
$resizableBar = 'Unknown: nvidia-smi BAR1 data is unavailable.'
if ($nvidiaSmi) {
    $query = & $nvidiaSmi.Source --query-gpu=name,driver_version,memory.total,memory.used,memory.free,pstate,pcie.link.gen.max,pcie.link.gen.current,pcie.link.width.max,pcie.link.width.current,compute_cap,pci.bus_id,clocks.current.graphics,clocks.current.memory --format=csv,noheader,nounits 2>$null
    if ($LASTEXITCODE -eq 0 -and $query) {
        $parts = ([string]$query | Select-Object -First 1).Split(',') | ForEach-Object { $_.Trim() }
        if ($parts.Count -ge 14) {
            $gpuSmi = [pscustomobject]@{
                Name = $parts[0]
                DriverVersion = $parts[1]
                DedicatedMemoryMiB = $parts[2]
                UsedMemoryMiB = $parts[3]
                FreeMemoryMiB = $parts[4]
                PerformanceState = $parts[5]
                PcieGenerationMax = $parts[6]
                PcieGenerationCurrent = $parts[7]
                PcieWidthMax = $parts[8]
                PcieWidthCurrent = $parts[9]
                ComputeCapability = $parts[10]
                PciBusId = $parts[11]
                GraphicsClockMHz = $parts[12]
                MemoryClockMHz = $parts[13]
            }
        }
    }

    # NVIDIA documents a BAR1 aperture close to framebuffer size as evidence
    # that the full VRAM range is mapped. This is an inference, not a BIOS flag.
    $bar1Output = & $nvidiaSmi.Source -q -d MEMORY 2>$null | Out-String
    if ($LASTEXITCODE -eq 0 -and $bar1Output) {
        $insideBar1 = $false
        foreach ($line in ($bar1Output -split "`r?`n")) {
            if (-not $insideBar1) {
                if ($line.Trim() -eq 'BAR1 Memory Usage') { $insideBar1 = $true }
                continue
            }
            if ([string]::IsNullOrWhiteSpace($line)) {
                if ($null -ne $bar1TotalMiB -and $null -ne $bar1UsedMiB -and $null -ne $bar1FreeMiB) { break }
                continue
            }
            if ($line -match '^\S') { break }
            if ($line -match '^\s*(Total|Used|Free)\s*:\s*([\d,]+)\s*MiB\s*$') {
                $value = [UInt64]($Matches[2] -replace ',', '')
                switch ($Matches[1]) {
                    'Total' { $bar1TotalMiB = $value }
                    'Used'  { $bar1UsedMiB = $value }
                    'Free'  { $bar1FreeMiB = $value }
                }
            }
        }
    }
    if ($bar1TotalMiB -ne $null -and $gpuSmi -and $gpuSmi.DedicatedMemoryMiB -match '^\d+$') {
        $vramMiB = [UInt64]$gpuSmi.DedicatedMemoryMiB
        if ($bar1TotalMiB -ge $vramMiB) {
            $resizableBar = "Likely enabled: BAR1 aperture $bar1TotalMiB MiB matches or exceeds the $vramMiB MiB framebuffer; verify the firmware setting in NVIDIA Control Panel."
        } else {
            $resizableBar = "Not confirmed: BAR1 aperture $bar1TotalMiB MiB is smaller than the $vramMiB MiB framebuffer; verify the firmware setting in NVIDIA Control Panel."
        }
    }
    if ($gpuSmi) {
        $gpuSmi | Add-Member -NotePropertyName Bar1TotalMiB -NotePropertyValue $bar1TotalMiB
        $gpuSmi | Add-Member -NotePropertyName Bar1UsedMiB -NotePropertyValue $bar1UsedMiB
        $gpuSmi | Add-Member -NotePropertyName Bar1FreeMiB -NotePropertyValue $bar1FreeMiB
    }
}

$pagingFiles = $null
try {
    $pagingFiles = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name PagingFiles -ErrorAction Stop).PagingFiles
} catch { }

$biosInfo = Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -ErrorAction SilentlyContinue
$report = [ordered]@{
    CapturedAt = (Get-Date).ToString('o')
    OperatingSystem = [ordered]@{
        ProductName = $osDisplayName
        DisplayVersion = $osKey.DisplayVersion
        Build = $osKey.CurrentBuild
        UBR = $osKey.UBR
        Architecture = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
        DxDiag = $dxDiag
    }
    CPU = [ordered]@{
        Name = $cpuName
        PhysicalCores = $physicalCores
        LogicalProcessors = $logicalProcessors
        Avx2 = [VictoryHardwareProbe]::SupportsAvx2()
        Note = if ($null -eq $physicalCores) { 'Physical core count unavailable through WMI.' } else { $null }
    }
    Motherboard = [ordered]@{
        Manufacturer = [string]$biosInfo.BaseBoardManufacturer
        Product = [string]$biosInfo.BaseBoardProduct
        Version = [string]$biosInfo.BaseBoardVersion
        BIOSVersion = [string]$biosInfo.BIOSVersion
    }
    RAM = [ordered]@{
        InstalledGiB = if ($memoryModules.Count -gt 0) { [Math]::Round(($memoryModules | Measure-Object -Property CapacityGiB -Sum).Sum, 2) } elseif ($installedPhysicalMemory -gt 0) { ConvertTo-GiB $installedPhysicalMemory } else { $null }
        UsablePhysicalGiB = ConvertTo-GiB ([UInt64]$memory.TotalPhysical)
        AvailableGiB = ConvertTo-GiB ([UInt64]$memory.AvailablePhysical)
        CommitLimitGiB = ConvertTo-GiB ([UInt64]$memory.TotalPageFile)
        AvailableCommitGiB = ConvertTo-GiB ([UInt64]$memory.AvailablePageFile)
        PagingFiles = $pagingFiles
        ModuleSpeedNote = if ($memoryModules.Count -eq 0) { 'DIMM SPD/speed is unavailable because Windows CIM/SMBIOS module data could not be read.' } else { $null }
        Modules = $memoryModules
    }
    GPU = [ordered]@{
        DxgiAdapters = @($adapters | ForEach-Object {
            [ordered]@{
                Name = $_.Description
                VendorId = ('0x{0:X4}' -f $_.VendorId)
                DeviceId = ('0x{0:X4}' -f $_.DeviceId)
                Revision = ('0x{0:X2}' -f $_.Revision)
                AdapterLuid = ('0x{0:X8}_0x{1:X8}' -f [UInt32](($_.AdapterLuid -shr 32) -band 0xFFFFFFFF), [UInt32]($_.AdapterLuid -band 0xFFFFFFFF))
                DedicatedVideoMemoryGiB = ConvertTo-GiB ([UInt64]$_.DedicatedVideoMemory)
                SharedSystemMemoryGiB = ConvertTo-GiB ([UInt64]$_.SharedSystemMemory)
            }
        })
        NvidiaSmi = $gpuSmi
        FirstDxgiAdapter = if ($firstDxgiAdapter) { $firstDxgiAdapter.Description } else { $null }
        NvidiaIsFirstDxgiAdapter = [bool]($nvidia -and $firstDxgiAdapter -and $nvidia.AdapterLuid -eq $firstDxgiAdapter.AdapterLuid)
        DefaultAdapterInference = 'D3D12CreateDevice(NULL) uses the first IDXGIFactory1 adapter; this probe records the IDXGIFactory1::EnumAdapters1 order. Confirm the adapter opened by VIctory in its own device log.'
        DxgiProbeProcessBudgetMiB = if ($dxgiBudget) { [Math]::Round($dxgiBudget.Budget / 1MB) } else { $null }
        DxgiProbeProcessUsageMiB = if ($dxgiBudget) { [Math]::Round($dxgiBudget.CurrentUsage / 1MB) } else { $null }
        DxgiProbeError = $dxgiBudgetError
        D3D12 = $d3d12
        ResizableBar = $resizableBar
        ResizableBarEvidence = 'Inference from nvidia-smi BAR1 aperture compared with framebuffer size, not a direct firmware setting query; BAR1 used/free are mapping aperture counters, not dedicated VRAM residency.'
        Note = 'DXGI budget/usage above belongs to this probe process. VIctory must query IDXGIAdapter3 from its own process for its effective budget.'
    }
}

$json = $report | ConvertTo-Json -Depth 8
if ($OutputPath) {
    $resolved = [System.IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path -Parent $resolved
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllText($resolved, $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Hardware report written to $resolved"
}
$report | ConvertTo-Json -Depth 8
