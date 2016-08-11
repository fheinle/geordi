Given /^I am using the kernel "(.+?)" and have these old kernels installed:$/ do |current, old|
  old_kernels = old.raw.flatten
  Util.should_receive(:kernels).and_return({:current => current, :old => old_kernels})
end
