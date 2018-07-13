require 'spec_helper_acceptance'

test_name 'fips'

describe 'fips' do
  let(:manifest) {
    <<-EOS
      include 'fips'
    EOS
  }

  hosts.each do |host|
    context 'default parameters and Enable FIPS' do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        set_hieradata_on(host, { 'simp_options::fips' => true })

        # Must be FIPS compliant!
        # This is typically set during `simp config`
        on(host, 'puppet config set digest_algorithm sha256')
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should require reboot on subsequent run' do
        result = apply_manifest_on(host, manifest, :catch_failures => true)
        expect(result.output).to include('fips => The status of the fips kernel parameter has changed')

        # Reboot to enable fips in the kernel
        host.reboot

        # run puppet again to clean the reboot notify provider files
        apply_manifest_on(host, manifest)
      end

      it 'should have kernel-level FIPS enabled on reboot' do
        result = on(host, 'puppet facts find `hostname` | grep fips_enabled')
        expect(result.output).to match(/true/i)
      end

      it 'should have the dracut-fips package installed' do
        result = on(host, 'puppet resource package dracut-fips')
        expect(result.output).to_not include("ensure => 'absent'")
      end

      it 'should have the dracut-fips-aesni package installed' do
        result = on(host, 'puppet facts')
        cpuflags = JSON.load(result.output)['values']['cpuinfo']['processor0']['flags']

        if cpuflags.include?('aes')
          result = on(host, 'puppet resource package dracut-fips-aesni')
          expect(result.output).to_not include("ensure => 'absent'")
        end
      end
    end

    context 'disabling FIPS at the kernel level' do
      it 'should disable fips' do
        set_hieradata_on(host, { 'simp_options::fips' => false })
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should require reboot on subsequent run' do
        result = apply_manifest_on(host, manifest, :catch_failures => true)
        expect(result.output).to include('fips => The status of the fips kernel parameter has changed')

        # Reboot to disable fips in the kernel
        host.reboot
      end

      it 'should have kernel-level FIPS disabled on reboot' do
        result = on(host, 'puppet facts find `hostname` | grep fips_enabled')
        expect(result.output).to match(/false/i)
      end

      it 'should not have the dracut-fips package installed' do
        result = on(host, 'puppet resource package dracut-fips')
        expect(result.output).to match(/ensure => '(absent|purged)'/)
      end
    end
  end
end
