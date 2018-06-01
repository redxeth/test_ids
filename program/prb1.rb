Flow.create do
  if dut.test_ids == 2
    func :t1, bin: 11
    func :t2, bin: 11
    func :t3, bin: 11
    func :t4, bin: 11
    func :t5, bin: 11
  else
    func :t1
    func :t2
    func :t3
    func :t3, bin: :none, sbin: :none
  end
end
