require 'spec_helper'

describe 'fips' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts){
        facts.merge({
        :root_dir_uuid => '123-456-789',
        :boot_dir_uuid => '123-456-790'
      }) }

      context "on #{os}" do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_package('nss') }

        context 'when_enabling_fips' do
          let(:params){{
            :enabled => true
          }}

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to create_kernel_parameter('fips').with_value('1')
            is_expected.to create_kernel_parameter('fips').that_notifies('Reboot_notify[fips]')
            is_expected.to create_package('dracut-fips').with_ensure('installed')
            is_expected.to create_package('dracut-fips').that_notifies('Exec[dracut_rebuild]')
            is_expected.to create_package('fipscheck').with_ensure('installed')
          }
          it { is_expected.to create_kernel_parameter('boot').with_value("UUID=123-456-790") }
          it { is_expected.to create_kernel_parameter('boot').that_notifies('Reboot_notify[fips]') }
          it { is_expected.to create_reboot_notify('fips') }

          context 'when boot is not a separate partition' do
            let(:facts){
              facts.merge({
              :root_dir_uuid => '123-456-789',
              :boot_dir_uuid => '123-456-789'
            }) }

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to create_kernel_parameter('fips').with_value('1')
              is_expected.to create_kernel_parameter('fips').that_notifies('Reboot_notify[fips]')
              is_expected.to create_package('dracut-fips').with_ensure('installed')
              is_expected.to create_package('dracut-fips').that_notifies('Exec[dracut_rebuild]')
              is_expected.to create_package('fipscheck').with_ensure('installed')
            }
            it { is_expected.to create_kernel_parameter('boot').with_ensure('absent') }
            it { is_expected.to create_reboot_notify('fips') }
          end
        end

        context 'when_enabling_fips and aes' do
          let(:facts){ facts.merge({
            :cpuinfo => { :processor0 => { :flags => ['aes'] }},
            :root_dir_uuid => '123-456-789',
            :boot_dir_uuid => '123-456-790'
          })}
          let(:params){{
            :enabled => true
          }}

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to create_kernel_parameter('fips').with_value('1')
            is_expected.to create_kernel_parameter('fips').that_notifies('Reboot_notify[fips]')
            is_expected.to create_package('dracut-fips-aesni').with_ensure('installed')
            is_expected.to create_package('dracut-fips-aesni').that_notifies('Exec[dracut_rebuild]')
            is_expected.to create_package('fipscheck').with_ensure('installed')
          }
          it { is_expected.to create_kernel_parameter('boot').with_value("UUID=123-456-790") }
          it { is_expected.to create_kernel_parameter('boot').that_notifies('Reboot_notify[fips]') }
          it { is_expected.to create_reboot_notify('fips') }
        end

        context 'when_disabling_fips and aes' do
          let(:facts){ facts.merge({
            :cpuinfo => { :processor0 => { :flags => ['aes'] }},
            :root_dir_uuid => '123-456-789',
            :boot_dir_uuid => '123-456-790'
          })}

          let(:params){{
            :enabled => false
          }}

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to create_kernel_parameter('fips').with_value('0')
            is_expected.to create_kernel_parameter('fips').that_notifies('Reboot_notify[fips]')
          }
          it {
            is_expected.to create_package('dracut-fips-aesni').with_ensure('absent').that_comes_before('Package[dracut-fips]')
            is_expected.to create_package('dracut-fips-aesni').that_notifies('Exec[dracut_rebuild]')
            is_expected.to create_package('dracut-fips').with_ensure('absent')
            is_expected.to create_package('dracut-fips').that_notifies('Exec[dracut_rebuild]')
          }
          it { is_expected.to create_reboot_notify('fips') }
        end
      end
    end
  end
end
