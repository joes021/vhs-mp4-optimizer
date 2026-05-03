using System;
using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Data;
using Avalonia.Platform;
using LibVLCSharp.Shared;

namespace VhsMp4Optimizer.App.Controls;

public sealed class EmbeddedVideoView : NativeControlHost
{
    public static readonly DirectProperty<EmbeddedVideoView, MediaPlayer?> MediaPlayerProperty =
        AvaloniaProperty.RegisterDirect<EmbeddedVideoView, MediaPlayer?>(
            nameof(MediaPlayer),
            view => view.MediaPlayer,
            (view, value) => view.MediaPlayer = value,
            defaultBindingMode: BindingMode.TwoWay);

    private MediaPlayer? _mediaPlayer;
    private IPlatformHandle? _platformHandle;

    public MediaPlayer? MediaPlayer
    {
        get => _mediaPlayer;
        set
        {
            var previous = _mediaPlayer;
            if (!SetAndRaise(MediaPlayerProperty, ref _mediaPlayer, value))
            {
                return;
            }

            if (previous is not null)
            {
                DetachPlayer(previous);
            }

            if (value is not null && _platformHandle is not null)
            {
                AttachPlayer(value, _platformHandle);
            }
        }
    }

    protected override IPlatformHandle CreateNativeControlCore(IPlatformHandle parent)
    {
        _platformHandle = base.CreateNativeControlCore(parent);
        if (_mediaPlayer is not null && _platformHandle is not null)
        {
            AttachPlayer(_mediaPlayer, _platformHandle);
        }

        return _platformHandle!;
    }

    protected override void DestroyNativeControlCore(IPlatformHandle control)
    {
        if (_mediaPlayer is not null)
        {
            DetachPlayer(_mediaPlayer);
        }

        _platformHandle = null;
        base.DestroyNativeControlCore(control);
    }

    private static void AttachPlayer(MediaPlayer player, IPlatformHandle handle)
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            player.Hwnd = handle.Handle;
            return;
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        {
            player.XWindow = (uint)handle.Handle;
            return;
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            player.NsObject = handle.Handle;
        }
    }

    private static void DetachPlayer(MediaPlayer player)
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            player.Hwnd = IntPtr.Zero;
            return;
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        {
            player.XWindow = 0;
            return;
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            player.NsObject = IntPtr.Zero;
        }
    }
}
