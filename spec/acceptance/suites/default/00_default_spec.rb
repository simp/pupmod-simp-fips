require 'spec_helper_acceptance'

test_name 'fips'

describe 'fips' do
  let(:manifest) do
    <<~EOS
      include 'fips'
    EOS
  end

  hosts.each do |host|
    # Exercise noop from a clean state: on a fresh node the Sicura console
    # previews the module with `puppet apply --noop`, which must not error. This
    # runs first, before FIPS is enabled, the digest algorithm is changed, or
    # the host is rebooted below -- so it is the genuine fresh-node preview.
    # Real behaviour (enabling FIPS, reboot, idempotence) is covered by the
    # applies that follow. A post-convergence noop check is deliberately
    # omitted: `puppet apply --noop --detailed-exitcodes` always exits 0.
    #
    # Unlike other modules in this rollout, there is no `before` package
    # removal: fips has no single managed package whose removal represents a
    # fresh node -- when FIPS is off (the clean-node default) it ensures
    # `dracut-fips` *absent* already, and `nss`/the fipscheck package are base
    # packages with dependents that cannot be removed. The value here is
    # confirming `include 'fips'` compiles and evaluates under --noop without
    # error (kernel_parameter, reboot_notify, and the refreshonly dracut exec
    # are all noop-safe), which is exactly what the console preview needs.
    context 'in noop mode from a clean state' do
      it 'applies without errors in noop mode' do
        apply_manifest_on(host, manifest, catch_failures: true, noop: true)
      end
    end

    context 'default parameters and Enable FIPS' do
      # Using puppet_apply as a helper
      it 'works with no errors' do
        set_hieradata_on(host, { 'simp_options::fips' => true })

        # Must be FIPS compliant!
        # This is typically set during `simp config`
        on(host, 'puppet config set digest_algorithm sha256')
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'requires reboot on subsequent run' do
        result = apply_manifest_on(host, manifest, catch_failures: true)
        expect(result.output).to include('fips => The status of the fips kernel parameter has changed')

        munge_ssh_crypto_policies(host)

        # Reboot to enable fips in the kernel
        host.reboot

        # run puppet again to clean the reboot notify provider files
        apply_manifest_on(host, manifest)
      end

      it 'has kernel-level FIPS enabled on reboot' do
        expect(pfact_on(host, 'fips_enabled')).to be true
      end

      it 'has the dracut-fips package installed' do
        result = on(host, 'puppet resource package dracut-fips')
        expect(result.output).not_to include("ensure => 'absent'")
      end

      it 'has the dracut-fips-aesni package installed' do
        cpuflags = pfact_on(host, 'cpuinfo.processor0.flags')

        if cpuflags.include?('aes')
          result = on(host, 'puppet resource package dracut-fips-aesni')
          expect(result.output).not_to include("ensure => 'absent'")
        end
      end
    end

    context 'disabling FIPS at the kernel level' do
      it 'disables fips' do
        set_hieradata_on(host, { 'simp_options::fips' => false })
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'requires reboot on subsequent run' do
        result = apply_manifest_on(host, manifest, catch_failures: true)
        expect(result.output).to include('fips => The status of the fips kernel parameter has changed')

        # Reboot to disable fips in the kernel
        host.reboot
      end

      it 'has kernel-level FIPS disabled on reboot' do
        expect(pfact_on(host, 'fips_enabled')).to be false
      end

      it 'has the dracut-fips package installed' do
        result = on(host, 'puppet resource package dracut-fips')
        expect(result.output).not_to include("ensure => 'absent'")
      end
    end
  end
end
